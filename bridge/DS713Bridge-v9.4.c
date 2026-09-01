/** @file
  DS713Bridge v9.4 FULL-STACK R2

  Generic rear-USB UEFI bridge for Synology DS713+ / Etron EJ168A.
  It deliberately loads and binds a complete EDK2 USB/storage/filesystem stack
  so boot media do not depend on the 2011 Granite Well upper USB stack.

  No persistent EFI variable writes. No OS name, UUID, serial or rear-port
  number is embedded. The only OS loader path is the standard removable-media
  path: \\EFI\\BOOT\\BOOTX64.EFI.

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
#include <Library/MemoryAllocationLib.h>
#include <Library/UefiApplicationEntryPoint.h>
#include <Library/UefiBootServicesTableLib.h>

#define ETRON_VENDOR_ID           0x1B6F
#define ETRON_EJ168_DEVICE_ID     0x7023
#define DISCOVERY_TRIES           300
#define DISCOVERY_STALL_US        100000
#define BINDING_PASSES            10
#define BINDING_STALL_US          100000

STATIC CHAR16 mBootPath[]       = L"\\EFI\\BOOT\\BOOTX64.EFI";
STATIC CHAR16 mXhciPath[]       = L"\\EFI\\DS713V94\\drivers\\XhciDxe.efi";
STATIC CHAR16 mUsbBusPath[]     = L"\\EFI\\DS713V94\\drivers\\UsbBusDxe.efi";
STATIC CHAR16 mUsbMassPath[]    = L"\\EFI\\DS713V94\\drivers\\UsbMassStorageDxe.efi";
STATIC CHAR16 mDiskIoPath[]     = L"\\EFI\\DS713V94\\drivers\\DiskIoDxe.efi";
STATIC CHAR16 mPartitionPath[]  = L"\\EFI\\DS713V94\\drivers\\PartitionDxe.efi";
STATIC CHAR16 mEnglishPath[]    = L"\\EFI\\DS713V94\\drivers\\EnglishDxe.efi";
STATIC CHAR16 mFatPath[]        = L"\\EFI\\DS713V94\\drivers\\Fat.efi";

typedef struct {
  EFI_HANDLE                  ImageHandle;
  EFI_DRIVER_BINDING_PROTOCOL *Binding;
  CHAR16                      *Path;
} V94_DRIVER;

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
  OUT V94_DRIVER *Driver
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
  IN V94_DRIVER *Driver,
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
  IN V94_DRIVER *Driver,
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
  V94_DRIVER Xhci;
  V94_DRIVER UsbBus;
  V94_DRIVER UsbMass;
  V94_DRIVER DiskIo;
  V94_DRIVER Partition;
  V94_DRIVER English;
  V94_DRIVER Fat;
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
  EFI_STATUS       Status;
  EFI_LOADED_IMAGE_PROTOCOL *LoadedImage;
  EFI_HANDLE       Etron;
  UINTN            Try;

  (VOID)SystemTable;
  LoadedImage = NULL;
  Etron = NULL;

  // Disable any inherited watchdog while constructing the storage stack.
  (VOID)gBS->SetWatchdogTimer (0, 0, 0, NULL);

  Status = gBS->HandleProtocol (
                  ImageHandle,
                  &gEfiLoadedImageProtocolGuid,
                  (VOID **)&LoadedImage
                  );
  if (EFI_ERROR (Status) || (LoadedImage == NULL)) {
    return EFI_LOAD_ERROR;
  }

  Status = FindEtron (&Etron);
  if (EFI_ERROR (Status)) {
    return Status;
  }

  Status = LoadFullStack (ImageHandle, LoadedImage->DeviceHandle, Etron);
  if (EFI_ERROR (Status)) {
    return Status;
  }

  // The full stack normally enumerates synchronously, but allow bounded time
  // for devices/partitions/filesystems that appear after a driver Start().
  for (Try = 0; Try < DISCOVERY_TRIES; ++Try) {
    Status = TryRearFilesystems (ImageHandle, Etron);
    if (Status != EFI_NOT_FOUND) {
      return Status;
    }
    gBS->Stall (DISCOVERY_STALL_US);
  }

  return EFI_TIMEOUT;
}
