/** @file
  DS713Bridge v9.5 SATA-POWER + FULL-STACK R2

  DS713+ front-key UEFI bridge. Before chainloading a rear USB OS, this version
  restores the Synology Cedarview internal-HDD power sequence (GPIO16, then
  GPIO20 after 200 ms) through the ICH10 LPC GPIO block. It then preserves the
  physically validated v9.4 EDK2 rear-USB full-stack behavior.

  No persistent EFI variable writes. No OS name, UUID, serial, disk model or
  rear-port number is embedded. The only OS loader path is the standard
  removable-media path: \\EFI\\BOOT\\BOOTX64.EFI.

  SPDX-License-Identifier: BSD-2-Clause
**/

#include <Uefi.h>

#include <Protocol/DevicePath.h>
#include <Protocol/DriverBinding.h>
#include <Protocol/LoadedImage.h>
#include <Protocol/PciIo.h>
#include <Protocol/SimpleFileSystem.h>

#include <Library/BaseMemoryLib.h>
#include <Library/DevicePathLib.h>
#include <Library/IoLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/UefiApplicationEntryPoint.h>
#include <Library/UefiBootServicesTableLib.h>

#define INTEL_VENDOR_ID             0x8086
#define LPC_SEGMENT                 0
#define LPC_BUS                     0
#define LPC_DEVICE                  31
#define LPC_FUNCTION                0
#define LPC_GPIOBASE_OFFSET         0x48
#define LPC_GPIOCTRL_OFFSET         0x4C
#define LPC_GPIOCTRL_ENABLE         0x10
#define LPC_GPIOBASE_MASK           0x0000FF80U

#define GPIO_USE_SEL_OFFSET         0x00
#define GPIO_IO_SEL_OFFSET          0x04
#define GPIO_LVL_OFFSET             0x0C
#define GPO_BLINK_OFFSET            0x18
#define HDD1_GPIO                   16
#define HDD2_GPIO                   20
#define HDD_POWER_STAGGER_US        200000

#define ETRON_VENDOR_ID             0x1B6F
#define ETRON_EJ168_DEVICE_ID       0x7023
#define DISCOVERY_TRIES             300
#define DISCOVERY_STALL_US          100000
#define BINDING_PASSES              10
#define BINDING_STALL_US            100000

STATIC CHAR16 mBootPath[]       = L"\\EFI\\BOOT\\BOOTX64.EFI";
// v9.5 intentionally reuses the physically validated v9.4 driver payload.
STATIC CHAR16 mXhciPath[]       = L"\\EFI\\DS713V94\\drivers\\XhciDxe.efi";
STATIC CHAR16 mUsbBusPath[]     = L"\\EFI\\DS713V94\\drivers\\UsbBusDxe.efi";
STATIC CHAR16 mUsbMassPath[]    = L"\\EFI\\DS713V94\\drivers\\UsbMassStorageDxe.efi";
STATIC CHAR16 mDiskIoPath[]     = L"\\EFI\\DS713V94\\drivers\\DiskIoDxe.efi";
STATIC CHAR16 mPartitionPath[]  = L"\\EFI\\DS713V94\\drivers\\PartitionDxe.efi";
STATIC CHAR16 mEnglishPath[]    = L"\\EFI\\DS713V94\\drivers\\EnglishDxe.efi";
STATIC CHAR16 mFatPath[]        = L"\\EFI\\DS713V94\\drivers\\Fat.efi";

typedef struct {
  EFI_HANDLE                   ImageHandle;
  EFI_DRIVER_BINDING_PROTOCOL  *Binding;
  CHAR16                       *Path;
} V95_DRIVER;

STATIC
BOOLEAN
BytesEqual (
  IN CONST UINT8 *A,
  IN CONST UINT8 *B,
  IN UINTN       Size
  )
{
  UINTN Index;

  for (Index = 0; Index < Size; ++Index) {
    if (A[Index] != B[Index]) {
      return FALSE;
    }
  }

  return TRUE;
}

STATIC
EFI_STATUS
FindIch10Lpc (
  OUT EFI_PCI_IO_PROTOCOL **LpcIo
  )
{
  EFI_STATUS           Status;
  EFI_HANDLE           *Handles;
  UINTN                HandleCount;
  UINTN                Index;
  EFI_PCI_IO_PROTOCOL  *PciIo;
  UINTN                Segment;
  UINTN                Bus;
  UINTN                Device;
  UINTN                Function;
  UINT32               Id;
  UINT32               ClassReg;
  UINT16               Vid;
  UINT8                BaseClass;
  UINT8                SubClass;

  if (LpcIo == NULL) {
    return EFI_INVALID_PARAMETER;
  }

  *LpcIo = NULL;
  Handles = NULL;
  HandleCount = 0;

  Status = gBS->LocateHandleBuffer (
                  ByProtocol,
                  &gEfiPciIoProtocolGuid,
                  NULL,
                  &HandleCount,
                  &Handles
                  );
  if (EFI_ERROR (Status)) {
    return Status;
  }

  for (Index = 0; Index < HandleCount; ++Index) {
    PciIo = NULL;
    Status = gBS->HandleProtocol (
                    Handles[Index],
                    &gEfiPciIoProtocolGuid,
                    (VOID **)&PciIo
                    );
    if (EFI_ERROR (Status) || (PciIo == NULL)) {
      continue;
    }

    Status = PciIo->GetLocation (PciIo, &Segment, &Bus, &Device, &Function);
    if (EFI_ERROR (Status) ||
        (Segment != LPC_SEGMENT) ||
        (Bus != LPC_BUS) ||
        (Device != LPC_DEVICE) ||
        (Function != LPC_FUNCTION)) {
      continue;
    }

    Id = MAX_UINT32;
    Status = PciIo->Pci.Read (
                          PciIo,
                          EfiPciIoWidthUint32,
                          0,
                          1,
                          &Id
                          );
    if (EFI_ERROR (Status)) {
      continue;
    }

    ClassReg = MAX_UINT32;
    Status = PciIo->Pci.Read (
                          PciIo,
                          EfiPciIoWidthUint32,
                          0x08,
                          1,
                          &ClassReg
                          );
    if (EFI_ERROR (Status)) {
      continue;
    }

    Vid = (UINT16)(Id & 0xFFFFU);
    BaseClass = (UINT8)((ClassReg >> 24) & 0xFFU);
    SubClass = (UINT8)((ClassReg >> 16) & 0xFFU);

    // DS713+ Cedarview uses the Intel LPC/ISA bridge at 0000:00:1f.0.
    if ((Vid == INTEL_VENDOR_ID) && (BaseClass == 0x06U) && (SubClass == 0x01U)) {
      *LpcIo = PciIo;
      break;
    }
  }

  if (Handles != NULL) {
    FreePool (Handles);
  }

  return (*LpcIo != NULL) ? EFI_SUCCESS : EFI_NOT_FOUND;
}

STATIC
EFI_STATUS
SetLegacyGpioOutputHigh (
  IN UINT16 GpioBase,
  IN UINT8  Pin
  )
{
  UINT32 Mask;
  UINT32 UseSel;
  UINT32 IoSel;
  UINT32 Level;
  UINT32 Blink;

  if (Pin >= 32U) {
    return EFI_UNSUPPORTED;
  }

  Mask = (UINT32)(1U << Pin);

  // Linux gpio-ich intentionally trusts BIOS GPIO_USE_SEL. Do the same and
  // refuse to repurpose a pin that firmware did not already expose as GPIO.
  UseSel = IoRead32 ((UINTN)GpioBase + GPIO_USE_SEL_OFFSET);
  if ((UseSel & Mask) == 0U) {
    return EFI_UNSUPPORTED;
  }

  // Mirror gpio-ich direction_output(): disable blink, set output level first,
  // then set direction to output. GPIO16/20 are both in the first 32-pin bank.
  Blink = IoRead32 ((UINTN)GpioBase + GPO_BLINK_OFFSET);
  Blink &= ~Mask;
  IoWrite32 ((UINTN)GpioBase + GPO_BLINK_OFFSET, Blink);

  Level = IoRead32 ((UINTN)GpioBase + GPIO_LVL_OFFSET);
  Level |= Mask;
  IoWrite32 ((UINTN)GpioBase + GPIO_LVL_OFFSET, Level);

  IoSel = IoRead32 ((UINTN)GpioBase + GPIO_IO_SEL_OFFSET);
  IoSel &= ~Mask;
  IoWrite32 ((UINTN)GpioBase + GPIO_IO_SEL_OFFSET, IoSel);

  IoSel = IoRead32 ((UINTN)GpioBase + GPIO_IO_SEL_OFFSET);
  Level = IoRead32 ((UINTN)GpioBase + GPIO_LVL_OFFSET);

  if (((IoSel & Mask) != 0U) || ((Level & Mask) == 0U)) {
    return EFI_DEVICE_ERROR;
  }

  return EFI_SUCCESS;
}

STATIC
EFI_STATUS
EnableInternalHddPower (
  VOID
  )
{
  EFI_STATUS           Status;
  EFI_PCI_IO_PROTOCOL  *LpcIo;
  UINT32               GpioBaseCfg;
  UINT16               GpioBase;
  UINT8                GpioCtrl;

  LpcIo = NULL;
  Status = FindIch10Lpc (&LpcIo);
  if (EFI_ERROR (Status) || (LpcIo == NULL)) {
    return EFI_NOT_FOUND;
  }

  GpioBaseCfg = 0;
  Status = LpcIo->Pci.Read (
                       LpcIo,
                       EfiPciIoWidthUint32,
                       LPC_GPIOBASE_OFFSET,
                       1,
                       &GpioBaseCfg
                       );
  if (EFI_ERROR (Status)) {
    return Status;
  }

  GpioBase = (UINT16)(GpioBaseCfg & LPC_GPIOBASE_MASK);
  if (GpioBase == 0U) {
    return EFI_NOT_READY;
  }

  GpioCtrl = 0;
  Status = LpcIo->Pci.Read (
                       LpcIo,
                       EfiPciIoWidthUint8,
                       LPC_GPIOCTRL_OFFSET,
                       1,
                       &GpioCtrl
                       );
  if (EFI_ERROR (Status)) {
    return Status;
  }

  if ((GpioCtrl & LPC_GPIOCTRL_ENABLE) == 0U) {
    GpioCtrl |= LPC_GPIOCTRL_ENABLE;
    Status = LpcIo->Pci.Write (
                         LpcIo,
                         EfiPciIoWidthUint8,
                         LPC_GPIOCTRL_OFFSET,
                         1,
                         &GpioCtrl
                         );
    if (EFI_ERROR (Status)) {
      return Status;
    }

    GpioCtrl = 0;
    Status = LpcIo->Pci.Read (
                         LpcIo,
                         EfiPciIoWidthUint8,
                         LPC_GPIOCTRL_OFFSET,
                         1,
                         &GpioCtrl
                         );
    if (EFI_ERROR (Status) || ((GpioCtrl & LPC_GPIOCTRL_ENABLE) == 0U)) {
      return EFI_DEVICE_ERROR;
    }
  }

  // Match Synology's DS713+ order: disk 1 (GPIO16), 200 ms, disk 2 (GPIO20).
  Status = SetLegacyGpioOutputHigh (GpioBase, HDD1_GPIO);
  if (EFI_ERROR (Status)) {
    return Status;
  }

  gBS->Stall (HDD_POWER_STAGGER_US);

  Status = SetLegacyGpioOutputHigh (GpioBase, HDD2_GPIO);
  if (EFI_ERROR (Status)) {
    return Status;
  }

  return EFI_SUCCESS;
}

STATIC
BOOLEAN
IsBelowController (
  IN EFI_HANDLE Child,
  IN EFI_HANDLE Controller
  )
{
  EFI_DEVICE_PATH_PROTOCOL *ChildPath;
  EFI_DEVICE_PATH_PROTOCOL *ControllerPath;
  UINTN ChildSize;
  UINTN ControllerSize;
  UINTN PrefixSize;

  ChildPath = DevicePathFromHandle (Child);
  ControllerPath = DevicePathFromHandle (Controller);
  if ((ChildPath == NULL) || (ControllerPath == NULL)) {
    return FALSE;
  }

  ChildSize = GetDevicePathSize (ChildPath);
  ControllerSize = GetDevicePathSize (ControllerPath);
  if (ControllerSize <= sizeof (EFI_DEVICE_PATH_PROTOCOL)) {
    return FALSE;
  }

  PrefixSize = ControllerSize - sizeof (EFI_DEVICE_PATH_PROTOCOL);
  if (ChildSize <= PrefixSize) {
    return FALSE;
  }

  return BytesEqual ((CONST UINT8 *)ControllerPath,
                     (CONST UINT8 *)ChildPath,
                     PrefixSize);
}

STATIC
EFI_STATUS
FindEtron (
  OUT EFI_HANDLE *Etron
  )
{
  EFI_STATUS          Status;
  EFI_HANDLE          *Handles;
  UINTN               HandleCount;
  UINTN               Index;
  EFI_PCI_IO_PROTOCOL *PciIo;
  UINT32              Id;
  UINT16              Vid;
  UINT16              Did;

  if (Etron == NULL) {
    return EFI_INVALID_PARAMETER;
  }

  *Etron = NULL;
  Handles = NULL;
  HandleCount = 0;

  Status = gBS->LocateHandleBuffer (
                  ByProtocol,
                  &gEfiPciIoProtocolGuid,
                  NULL,
                  &HandleCount,
                  &Handles
                  );
  if (EFI_ERROR (Status)) {
    return Status;
  }

  for (Index = 0; Index < HandleCount; ++Index) {
    PciIo = NULL;
    Status = gBS->HandleProtocol (
                    Handles[Index],
                    &gEfiPciIoProtocolGuid,
                    (VOID **)&PciIo
                    );
    if (EFI_ERROR (Status) || (PciIo == NULL)) {
      continue;
    }

    Id = MAX_UINT32;
    Status = PciIo->Pci.Read (
                          PciIo,
                          EfiPciIoWidthUint32,
                          0,
                          1,
                          &Id
                          );
    if (EFI_ERROR (Status)) {
      continue;
    }

    Vid = (UINT16)(Id & 0xFFFFU);
    Did = (UINT16)((Id >> 16) & 0xFFFFU);
    if ((Vid == ETRON_VENDOR_ID) && (Did == ETRON_EJ168_DEVICE_ID)) {
      *Etron = Handles[Index];
      break;
    }
  }

  if (Handles != NULL) {
    FreePool (Handles);
  }

  return (*Etron != NULL) ? EFI_SUCCESS : EFI_NOT_FOUND;
}

STATIC
EFI_STATUS
LoadDriver (
  IN  EFI_HANDLE ParentImage,
  IN  EFI_HANDLE BridgeDevice,
  IN  CHAR16     *Path,
  IN  BOOLEAN    NeedBinding,
  OUT V95_DRIVER *Driver
  )
{
  EFI_STATUS               Status;
  EFI_DEVICE_PATH_PROTOCOL *FilePath;

  if ((Path == NULL) || (Driver == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  ZeroMem (Driver, sizeof (*Driver));
  Driver->Path = Path;

  FilePath = FileDevicePath (BridgeDevice, Path);
  if (FilePath == NULL) {
    return EFI_OUT_OF_RESOURCES;
  }

  Status = gBS->LoadImage (
                  FALSE,
                  ParentImage,
                  FilePath,
                  NULL,
                  0,
                  &Driver->ImageHandle
                  );
  FreePool (FilePath);
  if (EFI_ERROR (Status)) {
    if (Driver->ImageHandle != NULL) {
      (VOID)gBS->UnloadImage (Driver->ImageHandle);
      Driver->ImageHandle = NULL;
    }
    return Status;
  }

  Status = gBS->StartImage (Driver->ImageHandle, NULL, NULL);
  if (EFI_ERROR (Status)) {
    (VOID)gBS->UnloadImage (Driver->ImageHandle);
    Driver->ImageHandle = NULL;
    return Status;
  }

  if (!NeedBinding) {
    return EFI_SUCCESS;
  }

  Status = gBS->HandleProtocol (
                  Driver->ImageHandle,
                  &gEfiDriverBindingProtocolGuid,
                  (VOID **)&Driver->Binding
                  );
  if (EFI_ERROR (Status) || (Driver->Binding == NULL)) {
    return EFI_NOT_FOUND;
  }

  return EFI_SUCCESS;
}

STATIC
EFI_STATUS
StartBindingOnController (
  IN V95_DRIVER *Driver,
  IN EFI_HANDLE Controller,
  OUT BOOLEAN   *Started
  )
{
  EFI_STATUS Status;

  if ((Driver == NULL) || (Driver->Binding == NULL) ||
      (Controller == NULL) || (Started == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  *Started = FALSE;

  Status = Driver->Binding->Supported (Driver->Binding, Controller, NULL);
  if (Status == EFI_ALREADY_STARTED) {
    return EFI_SUCCESS;
  }
  if (EFI_ERROR (Status)) {
    return Status;
  }

  Status = Driver->Binding->Start (Driver->Binding, Controller, NULL);
  if (Status == EFI_ALREADY_STARTED) {
    return EFI_SUCCESS;
  }
  if (!EFI_ERROR (Status)) {
    *Started = TRUE;
  }

  return Status;
}

STATIC
EFI_STATUS
RunBindingPass (
  IN V95_DRIVER *Driver,
  IN EFI_HANDLE Etron,
  OUT UINTN     *StartedCount
  )
{
  EFI_STATUS Status;
  EFI_STATUS LastStatus;
  EFI_HANDLE *Handles;
  UINTN HandleCount;
  UINTN Index;
  BOOLEAN Started;

  if ((Driver == NULL) || (Driver->Binding == NULL) ||
      (Etron == NULL) || (StartedCount == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  *StartedCount = 0;
  Handles = NULL;
  HandleCount = 0;
  LastStatus = EFI_NOT_FOUND;

  Status = gBS->LocateHandleBuffer (
                  AllHandles,
                  NULL,
                  NULL,
                  &HandleCount,
                  &Handles
                  );
  if (EFI_ERROR (Status)) {
    return Status;
  }

  for (Index = 0; Index < HandleCount; ++Index) {
    if ((Handles[Index] != Etron) && !IsBelowController (Handles[Index], Etron)) {
      continue;
    }

    Started = FALSE;
    Status = StartBindingOnController (Driver, Handles[Index], &Started);
    if (!EFI_ERROR (Status)) {
      LastStatus = EFI_SUCCESS;
      if (Started) {
        ++(*StartedCount);
      }
    }
  }

  FreePool (Handles);
  return LastStatus;
}

STATIC
EFI_STATUS
StartOsLoader (
  IN EFI_HANDLE ParentImage,
  IN EFI_HANDLE FileSystem
  )
{
  EFI_STATUS               Status;
  EFI_DEVICE_PATH_PROTOCOL *Path;
  EFI_HANDLE               Child;

  Child = NULL;
  Path = FileDevicePath (FileSystem, mBootPath);
  if (Path == NULL) {
    return EFI_OUT_OF_RESOURCES;
  }

  Status = gBS->LoadImage (TRUE, ParentImage, Path, NULL, 0, &Child);
  FreePool (Path);

  if (EFI_ERROR (Status)) {
    if ((Status == EFI_SECURITY_VIOLATION) && (Child != NULL)) {
      (VOID)gBS->UnloadImage (Child);
    }
    return Status;
  }

  Status = gBS->SetWatchdogTimer (300, 0, 0, NULL);
  if (EFI_ERROR (Status)) {
    return Status;
  }

  Status = gBS->StartImage (Child, NULL, NULL);

  // If control returns, the OS loader did not complete the boot hand-off.
  (VOID)gBS->SetWatchdogTimer (0, 0, 0, NULL);
  return EFI_ERROR (Status) ? Status : EFI_ABORTED;
}

STATIC
BOOLEAN
CandidateFailureIsLocal (
  IN EFI_STATUS Status
  )
{
  return (BOOLEAN)(
           (Status == EFI_NOT_FOUND) ||
           (Status == EFI_NO_MEDIA) ||
           (Status == EFI_MEDIA_CHANGED) ||
           (Status == EFI_LOAD_ERROR) ||
           (Status == EFI_UNSUPPORTED) ||
           (Status == EFI_SECURITY_VIOLATION) ||
           (Status == EFI_ACCESS_DENIED) ||
           (Status == EFI_ABORTED)
           );
}

STATIC
EFI_STATUS
TryRearFilesystems (
  IN EFI_HANDLE ParentImage,
  IN EFI_HANDLE Etron
  )
{
  EFI_STATUS Status;
  EFI_HANDLE *Handles;
  UINTN HandleCount;
  UINTN Index;

  Handles = NULL;
  HandleCount = 0;

  Status = gBS->LocateHandleBuffer (
                  ByProtocol,
                  &gEfiSimpleFileSystemProtocolGuid,
                  NULL,
                  &HandleCount,
                  &Handles
                  );
  if (EFI_ERROR (Status)) {
    return Status;
  }

  for (Index = 0; Index < HandleCount; ++Index) {
    if (!IsBelowController (Handles[Index], Etron)) {
      continue;
    }

    Status = StartOsLoader (ParentImage, Handles[Index]);
    if (CandidateFailureIsLocal (Status)) {
      continue;
    }

    FreePool (Handles);
    return Status;
  }

  FreePool (Handles);
  return EFI_NOT_FOUND;
}

STATIC
EFI_STATUS
LoadFullStack (
  IN EFI_HANDLE ParentImage,
  IN EFI_HANDLE BridgeDevice,
  IN EFI_HANDLE Etron
  )
{
  EFI_STATUS Status;
  V95_DRIVER Xhci;
  V95_DRIVER UsbBus;
  V95_DRIVER UsbMass;
  V95_DRIVER DiskIo;
  V95_DRIVER Partition;
  V95_DRIVER English;
  V95_DRIVER Fat;
  BOOLEAN Started;
  UINTN Pass;
  UINTN Progress;
  UINTN Count;

  Status = LoadDriver (ParentImage, BridgeDevice, mXhciPath, TRUE, &Xhci);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  Status = LoadDriver (ParentImage, BridgeDevice, mUsbBusPath, TRUE, &UsbBus);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  Status = LoadDriver (ParentImage, BridgeDevice, mUsbMassPath, TRUE, &UsbMass);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  Status = LoadDriver (ParentImage, BridgeDevice, mDiskIoPath, TRUE, &DiskIo);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  Status = LoadDriver (ParentImage, BridgeDevice, mPartitionPath, TRUE, &Partition);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  Status = LoadDriver (ParentImage, BridgeDevice, mEnglishPath, FALSE, &English);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  Status = LoadDriver (ParentImage, BridgeDevice, mFatPath, TRUE, &Fat);
  if (EFI_ERROR (Status)) {
    return Status;
  }

  Started = FALSE;
  Status = StartBindingOnController (&Xhci, Etron, &Started);
  if (EFI_ERROR (Status)) {
    return Status;
  }

  for (Pass = 0; Pass < BINDING_PASSES; ++Pass) {
    Progress = 0;

    Count = 0;
    (VOID)RunBindingPass (&UsbBus, Etron, &Count);
    Progress += Count;

    Count = 0;
    (VOID)RunBindingPass (&UsbMass, Etron, &Count);
    Progress += Count;

    Count = 0;
    (VOID)RunBindingPass (&DiskIo, Etron, &Count);
    Progress += Count;

    Count = 0;
    (VOID)RunBindingPass (&Partition, Etron, &Count);
    Progress += Count;

    Count = 0;
    (VOID)RunBindingPass (&Fat, Etron, &Count);
    Progress += Count;

    if (Progress == 0) {
      break;
    }

    gBS->Stall (BINDING_STALL_US);
  }

  return EFI_SUCCESS;
}

EFI_STATUS
EFIAPI
UefiMain (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS                 Status;
  EFI_LOADED_IMAGE_PROTOCOL  *LoadedImage;
  EFI_HANDLE                 Etron;
  UINTN                      Try;

  (VOID)SystemTable;
  LoadedImage = NULL;
  Etron = NULL;

  // Disable any inherited watchdog before hardware bring-up.
  (VOID)gBS->SetWatchdogTimer (0, 0, 0, NULL);

  Status = gBS->HandleProtocol (
                  ImageHandle,
                  &gEfiLoadedImageProtocolGuid,
                  (VOID **)&LoadedImage
                  );
  if (EFI_ERROR (Status) || (LoadedImage == NULL)) {
    return EFI_LOAD_ERROR;
  }

  // Do this before Etron/full-stack discovery so the disks are already
  // spinning by the time the chainloaded Linux kernel starts AHCI probing.
  // SATA power-up is fail-open for boot compatibility: the GPIO routine itself
  // refuses unsafe pin muxing, while a power-stage failure must not regress the
  // already validated v9.4 rear-USB boot path.
  (VOID)EnableInternalHddPower ();

  Status = FindEtron (&Etron);
  if (EFI_ERROR (Status)) {
    return Status;
  }

  Status = LoadFullStack (ImageHandle, LoadedImage->DeviceHandle, Etron);
  if (EFI_ERROR (Status)) {
    return Status;
  }

  for (Try = 0; Try < DISCOVERY_TRIES; ++Try) {
    Status = TryRearFilesystems (ImageHandle, Etron);
    if (Status != EFI_NOT_FOUND) {
      return Status;
    }
    gBS->Stall (DISCOVERY_STALL_US);
  }

  return EFI_TIMEOUT;
}
