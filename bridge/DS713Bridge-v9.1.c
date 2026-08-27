/*
 * DS713Bridge v9.1
 *
 * Minimal UEFI bootstrap for Synology DS713+.
 *
 * The SAME bridge medium can live either:
 *   - in the front USB port (Intel EHCI USB(1,...)), or
 *   - in the internal DOM position (Intel EHCI USB(0,...)).
 *
 * Boot policy:
 *   1. If the bridge itself is on the front port, do NOT scan visible USB
 *      filesystems at all; go straight to rear xHCI initialization.
 *   2. If the bridge is on the DOM port, consider only filesystems whose
 *      first USB node below Intel 00:1d.7 is physical front port 1.
 *   3. Never chainload the bridge filesystem itself (handle + exact device
 *      path equality guard).
 *   4. If no front loader boots, find Etron EJ168 (1b6f:7023), load the
 *      proven XhciDxe, and preserve the validated two non-recursive
 *      ConnectController() calls.
 *   5. Accept a bootable filesystem behind either Etron rear port. No rear
 *      port number, OS, filesystem UUID, disk serial, or Boot#### is coded.
 *   6. Chainload only the standard x86-64 removable loader:
 *        \\EFI\\BOOT\\BOOTX64.EFI
 *
 * No menu, graphics, recursive connect, active polling, NVRAM boot-policy
 * writes, rEFInd, or generic EFI-file scan.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <efi.h>
#include <efilib.h>
#include <efipciio.h>

#define ETRON_VENDOR_ID          0x1B6F
#define ETRON_EJ168_DEVICE_ID    0x7023
#define ENUM_TIMEOUT_100NS       300000000ULL
#define V91_TIMING_MAGIC         0x5639314dU /* "V91M" */
#define V91_TIMING_VERSION       1
#define V91_STAGE_COUNT          7
#define V91_SOURCE_NONE          0
#define V91_SOURCE_FRONT_USB     1
#define V91_SOURCE_REAR_ETRON    2

/* DS713+ Intel EHCI path observed as Pci(0x1d,0x7)/USB(port,interface). */
#define DS713_EHCI_PCI_DEVICE    0x1D
#define DS713_EHCI_PCI_FUNCTION  0x07
#define DS713_FRONT_USB_PORT     0x01

static CHAR16 XHCI_PATH[] = L"\\EFI\\DS713\\XhciDxe.efi";
static CHAR16 BOOT_PATH[] = L"\\EFI\\BOOT\\BOOTX64.EFI";
static CHAR16 TIMING_NAME[] = L"DS713V91Timing";

static EFI_GUID TimingGuid = {
    0xb38865f1, 0xd61d, 0x4f4f,
    {0x91, 0x76, 0xf0, 0x60, 0x4d, 0x2c, 0x95, 0x91}
};

typedef struct {
    UINT16 year;
    UINT8 month;
    UINT8 day;
    UINT8 hour;
    UINT8 minute;
    UINT8 second;
    UINT8 valid;
    UINT32 nanosecond;
    INT16 timezone;
    UINT8 daylight;
    UINT8 reserved;
} V91_TIME;

typedef struct {
    UINT32 magic;
    UINT16 version;
    UINT16 stage_count;
    UINT32 source;
    UINT32 status32;
    V91_TIME stage[V91_STAGE_COUNT];
} V91_TIMING;

static V91_TIMING g_timing;

static VOID
record_stage(UINTN index)
{
    EFI_TIME t;
    EFI_STATUS st;
    V91_TIME *out;

    if (index >= V91_STAGE_COUNT)
        return;

    SetMem(&t, sizeof(t), 0);
    st = uefi_call_wrapper(RT->GetTime, 2, &t, NULL);
    if (EFI_ERROR(st))
        return;

    out = &g_timing.stage[index];
    out->year = t.Year;
    out->month = t.Month;
    out->day = t.Day;
    out->hour = t.Hour;
    out->minute = t.Minute;
    out->second = t.Second;
    out->valid = 1;
    out->nanosecond = t.Nanosecond;
    out->timezone = t.TimeZone;
    out->daylight = t.Daylight;
    out->reserved = 0;
}

static VOID
publish_timing(EFI_STATUS status)
{
    g_timing.status32 = (UINT32)status;
    (void)uefi_call_wrapper(RT->SetVariable, 5,
                            TIMING_NAME,
                            &TimingGuid,
                            EFI_VARIABLE_BOOTSERVICE_ACCESS |
                            EFI_VARIABLE_RUNTIME_ACCESS,
                            sizeof(g_timing),
                            &g_timing);
}

static BOOLEAN
bytes_equal(const UINT8 *a, const UINT8 *b, UINTN size)
{
    UINTN i;

    for (i = 0; i < size; ++i) {
        if (a[i] != b[i])
            return FALSE;
    }

    return TRUE;
}

static UINTN
device_path_node_size(const EFI_DEVICE_PATH *node)
{
    if (node == NULL)
        return 0;

    return (UINTN)node->Length[0] | ((UINTN)node->Length[1] << 8);
}

/*
 * UEFI LoadedImage.DeviceHandle is the canonical source device handle.
 * Exact device-path equality is an additional guard for old firmware that
 * might expose another handle for the same filesystem/partition.
 */
static BOOLEAN
same_device(EFI_HANDLE a, EFI_HANDLE b)
{
    EFI_DEVICE_PATH *a_path;
    EFI_DEVICE_PATH *b_path;
    UINTN a_size;
    UINTN b_size;

    if (a == b)
        return TRUE;

    a_path = DevicePathFromHandle(a);
    b_path = DevicePathFromHandle(b);
    if (a_path == NULL || b_path == NULL)
        return FALSE;

    a_size = DevicePathSize(a_path);
    b_size = DevicePathSize(b_path);
    if (a_size != b_size)
        return FALSE;

    return bytes_equal((const UINT8 *)a_path,
                       (const UINT8 *)b_path,
                       a_size);
}

/*
 * Return TRUE only when the FIRST USB child below the DS713+ Intel EHCI
 * controller is physical port 1 (front). This deliberately distinguishes:
 *
 *   Pci(0x1d,0x7)/USB(0,...)  internal DOM position
 *   Pci(0x1d,0x7)/USB(1,...)  front USB position
 *
 * Descendants of a hub plugged into the front still match because only the
 * first USB node below EHCI decides the physical port.
 */
static BOOLEAN
is_ds713_front_usb(EFI_HANDLE handle)
{
    EFI_DEVICE_PATH *node;
    BOOLEAN below_ds713_ehci = FALSE;

    node = DevicePathFromHandle(handle);
    if (node == NULL)
        return FALSE;

    while (!IsDevicePathEnd(node)) {
        UINTN size = device_path_node_size(node);
        const UINT8 *raw = (const UINT8 *)node;

        if (size < sizeof(EFI_DEVICE_PATH))
            return FALSE;

        if (DevicePathType(node) == HARDWARE_DEVICE_PATH &&
            DevicePathSubType(node) == HW_PCI_DP && size >= 6) {
            /* PCI_DEVICE_PATH bytes: Header, Function, Device. */
            below_ds713_ehci =
                (raw[4] == DS713_EHCI_PCI_FUNCTION &&
                 raw[5] == DS713_EHCI_PCI_DEVICE);
        } else if (below_ds713_ehci &&
                   DevicePathType(node) == MESSAGING_DEVICE_PATH &&
                   DevicePathSubType(node) == MSG_USB_DP && size >= 6) {
            /* USB_DEVICE_PATH bytes: Header, ParentPortNumber, Interface. */
            return raw[4] == DS713_FRONT_USB_PORT;
        }

        node = NextDevicePathNode(node);
    }

    return FALSE;
}

static BOOLEAN
is_below_controller(EFI_HANDLE handle, EFI_HANDLE controller)
{
    EFI_DEVICE_PATH *child_path;
    EFI_DEVICE_PATH *controller_path;
    UINTN child_size;
    UINTN controller_size;
    UINTN prefix_size;

    child_path = DevicePathFromHandle(handle);
    controller_path = DevicePathFromHandle(controller);

    if (child_path == NULL || controller_path == NULL)
        return FALSE;

    child_size = DevicePathSize(child_path);
    controller_size = DevicePathSize(controller_path);

    if (controller_size <= sizeof(EFI_DEVICE_PATH))
        return FALSE;

    prefix_size = controller_size - sizeof(EFI_DEVICE_PATH);

    if (child_size <= prefix_size)
        return FALSE;

    return bytes_equal((const UINT8 *)controller_path,
                       (const UINT8 *)child_path,
                       prefix_size);
}

static EFI_STATUS
find_etron(EFI_HANDLE *etron)
{
    EFI_HANDLE *handles = NULL;
    UINTN count = 0;
    UINTN i;
    EFI_STATUS st;

    *etron = NULL;

    st = LibLocateHandle(ByProtocol,
                         &PciIoProtocol,
                         NULL,
                         &count,
                         &handles);
    if (EFI_ERROR(st))
        return st;

    for (i = 0; i < count; ++i) {
        EFI_PCI_IO_PROTOCOL *pci = NULL;
        UINT32 id = 0xFFFFFFFFU;
        UINT16 vid;
        UINT16 did;

        st = uefi_call_wrapper(BS->HandleProtocol, 3,
                               handles[i],
                               &PciIoProtocol,
                               (VOID **)&pci);
        if (EFI_ERROR(st) || pci == NULL)
            continue;

        st = uefi_call_wrapper(pci->Pci.Read, 5,
                               pci,
                               EfiPciIoWidthUint32,
                               0,
                               1,
                               &id);
        if (EFI_ERROR(st))
            continue;

        vid = (UINT16)(id & 0xFFFFU);
        did = (UINT16)((id >> 16) & 0xFFFFU);

        if (vid == ETRON_VENDOR_ID && did == ETRON_EJ168_DEVICE_ID) {
            *etron = handles[i];
            break;
        }
    }

    if (handles != NULL)
        FreePool(handles);

    return (*etron != NULL) ? EFI_SUCCESS : EFI_NOT_FOUND;
}

static EFI_STATUS
load_xhci(EFI_HANDLE image,
          EFI_HANDLE bridge_device,
          EFI_HANDLE *driver_image)
{
    EFI_DEVICE_PATH *path;
    EFI_STATUS st;

    *driver_image = NULL;

    path = FileDevicePath(bridge_device, XHCI_PATH);
    if (path == NULL)
        return EFI_OUT_OF_RESOURCES;

    st = uefi_call_wrapper(BS->LoadImage, 6,
                           FALSE,
                           image,
                           path,
                           NULL,
                           0,
                           driver_image);
    FreePool(path);

    if (EFI_ERROR(st))
        return st;

    st = uefi_call_wrapper(BS->StartImage, 3,
                           *driver_image,
                           NULL,
                           NULL);

    if (EFI_ERROR(st)) {
        uefi_call_wrapper(BS->UnloadImage, 1, *driver_image);
        *driver_image = NULL;
    }

    return st;
}

static EFI_STATUS
connect_rear_stack(EFI_HANDLE etron, EFI_HANDLE xhci_driver)
{
    EFI_HANDLE driver_list[2];
    EFI_STATUS st;

    driver_list[0] = xhci_driver;
    driver_list[1] = NULL;

    /* Bind only the known XhciDxe first. */
    st = uefi_call_wrapper(BS->ConnectController, 4,
                           etron,
                           driver_list,
                           NULL,
                           FALSE);
    if (EFI_ERROR(st))
        return st;

    /* One non-recursive generic pass lets UsbBusDxe bind to xHCI. */
    st = uefi_call_wrapper(BS->ConnectController, 4,
                           etron,
                           NULL,
                           NULL,
                           FALSE);

    if (st == EFI_NOT_FOUND)
        return EFI_SUCCESS;

    return st;
}

static EFI_STATUS
start_standard_loader(EFI_HANDLE image,
                      EFI_HANDLE filesystem,
                      UINT32 source)
{
    EFI_DEVICE_PATH *path;
    EFI_HANDLE child = NULL;
    EFI_STATUS st;

    path = FileDevicePath(filesystem, BOOT_PATH);
    if (path == NULL)
        return EFI_OUT_OF_RESOURCES;

    st = uefi_call_wrapper(BS->LoadImage, 6,
                           FALSE,
                           image,
                           path,
                           NULL,
                           0,
                           &child);
    FreePool(path);

    if (EFI_ERROR(st))
        return st;

    g_timing.source = source;
    record_stage(6);
    publish_timing(EFI_SUCCESS);

    st = uefi_call_wrapper(BS->StartImage, 3,
                           child,
                           NULL,
                           NULL);

    if (EFI_ERROR(st))
        uefi_call_wrapper(BS->UnloadImage, 1, child);

    publish_timing(st);
    return st;
}

/*
 * Front/recovery policy is executed ONLY when the bridge itself is on DOM.
 * The scan accepts exactly DS713+ front-port descendants and nothing else.
 */
static EFI_STATUS
try_front_bootable(EFI_HANDLE image, EFI_HANDLE bridge_device)
{
    EFI_HANDLE *handles = NULL;
    UINTN count = 0;
    UINTN i;
    EFI_STATUS st;

    st = LibLocateHandle(ByProtocol,
                         &FileSystemProtocol,
                         NULL,
                         &count,
                         &handles);
    if (EFI_ERROR(st))
        return st;

    for (i = 0; i < count; ++i) {
        EFI_HANDLE handle = handles[i];

        if (same_device(handle, bridge_device))
            continue;

        if (!is_ds713_front_usb(handle))
            continue;

        st = start_standard_loader(image,
                                   handle,
                                   V91_SOURCE_FRONT_USB);

        /* Any per-candidate failure simply falls through to another candidate
         * or ultimately to rear boot. Fatal bridge setup errors happen later.
         */
        if (st == EFI_SUCCESS) {
            FreePool(handles);
            return st;
        }
    }

    FreePool(handles);
    return EFI_NOT_FOUND;
}

static BOOLEAN
candidate_failure_is_local(EFI_STATUS st)
{
    return st == EFI_NOT_FOUND ||
           st == EFI_NO_MEDIA ||
           st == EFI_MEDIA_CHANGED ||
           st == EFI_DEVICE_ERROR ||
           st == EFI_LOAD_ERROR ||
           st == EFI_UNSUPPORTED ||
           st == EFI_SECURITY_VIOLATION ||
           st == EFI_ACCESS_DENIED;
}

static EFI_STATUS
drain_new_filesystems(EFI_HANDLE image,
                      EFI_HANDLE etron,
                      VOID *registration)
{
    EFI_STATUS st;

    for (;;) {
        EFI_HANDLE handle = NULL;
        UINTN size = sizeof(handle);

        st = uefi_call_wrapper(BS->LocateHandle, 5,
                               ByRegisterNotify,
                               NULL,
                               registration,
                               &size,
                               &handle);

        if (st == EFI_NOT_FOUND)
            break;

        if (EFI_ERROR(st))
            return st;

        if (!is_below_controller(handle, etron))
            continue;

        record_stage(5);
        st = start_standard_loader(image,
                                   handle,
                                   V91_SOURCE_REAR_ETRON);

        if (candidate_failure_is_local(st))
            continue;

        return st;
    }

    return EFI_NOT_FOUND;
}

EFI_STATUS
efi_main(EFI_HANDLE image, EFI_SYSTEM_TABLE *system_table)
{
    EFI_LOADED_IMAGE *loaded = NULL;
    EFI_HANDLE etron = NULL;
    EFI_HANDLE xhci_driver = NULL;
    EFI_EVENT fs_event = NULL;
    EFI_EVENT timeout_event = NULL;
    EFI_EVENT wait_events[2];
    VOID *fs_registration = NULL;
    EFI_STATUS st;
    UINTN event_index;
    BOOLEAN bridge_on_front;

    InitializeLib(image, system_table);

    SetMem(&g_timing, sizeof(g_timing), 0);
    g_timing.magic = V91_TIMING_MAGIC;
    g_timing.version = V91_TIMING_VERSION;
    g_timing.stage_count = V91_STAGE_COUNT;
    g_timing.source = V91_SOURCE_NONE;
    record_stage(0);

    uefi_call_wrapper(BS->SetWatchdogTimer, 4, 0, 0, 0, NULL);

    st = uefi_call_wrapper(BS->HandleProtocol, 3,
                           image,
                           &LoadedImageProtocol,
                           (VOID **)&loaded);
    if (EFI_ERROR(st) || loaded == NULL) {
        publish_timing(EFI_LOAD_ERROR);
        return EFI_LOAD_ERROR;
    }

    /*
     * Location-independent bridge behavior:
     *   front bridge -> no front scan at all (fastest, recursion impossible)
     *   DOM bridge   -> scan only the physical front-port branch
     */
    bridge_on_front = is_ds713_front_usb(loaded->DeviceHandle);
    if (!bridge_on_front)
        (void)try_front_bootable(image, loaded->DeviceHandle);
    record_stage(1);

    st = find_etron(&etron);
    if (EFI_ERROR(st))
        goto out;
    record_stage(2);

    /* Register before xHCI so synchronous SimpleFS installations are caught. */
    st = uefi_call_wrapper(BS->CreateEvent, 5,
                           0,
                           TPL_APPLICATION,
                           NULL,
                           NULL,
                           &fs_event);
    if (EFI_ERROR(st))
        goto out;

    st = uefi_call_wrapper(BS->RegisterProtocolNotify, 3,
                           &FileSystemProtocol,
                           fs_event,
                           &fs_registration);
    if (EFI_ERROR(st))
        goto out;

    st = uefi_call_wrapper(BS->CreateEvent, 5,
                           EVT_TIMER,
                           TPL_APPLICATION,
                           NULL,
                           NULL,
                           &timeout_event);
    if (EFI_ERROR(st))
        goto out;

    st = load_xhci(image, loaded->DeviceHandle, &xhci_driver);
    if (EFI_ERROR(st))
        goto out;
    record_stage(3);

    st = connect_rear_stack(etron, xhci_driver);
    if (EFI_ERROR(st))
        goto out;
    record_stage(4);

    /* Failure ceiling only; successful boot is event-driven and immediate. */
    st = uefi_call_wrapper(BS->SetTimer, 3,
                           timeout_event,
                           TimerRelative,
                           ENUM_TIMEOUT_100NS);
    if (EFI_ERROR(st))
        goto out;

    wait_events[0] = fs_event;
    wait_events[1] = timeout_event;

    for (;;) {
        st = drain_new_filesystems(image, etron, fs_registration);
        if (st != EFI_NOT_FOUND)
            goto out;

        st = uefi_call_wrapper(BS->WaitForEvent, 3,
                               2,
                               wait_events,
                               &event_index);
        if (EFI_ERROR(st))
            goto out;

        if (event_index == 1) {
            st = EFI_TIMEOUT;
            goto out;
        }
    }

out:
    publish_timing(st);

    if (timeout_event != NULL)
        uefi_call_wrapper(BS->CloseEvent, 1, timeout_event);

    if (fs_event != NULL)
        uefi_call_wrapper(BS->CloseEvent, 1, fs_event);

    /* Never unload XhciDxe after successful binding. */
    return st;
}
