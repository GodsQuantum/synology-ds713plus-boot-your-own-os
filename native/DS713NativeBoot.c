/** @file
  DS713NativeBoot N3 - native rear-USB full-stack

  DS713+ firmware-resident UEFI bootstrap. Before chainloading a rear USB OS, this version
  restores the Synology Cedarview internal-HDD power sequence (GPIO16, then
  GPIO20 after 200 ms) through the ICH10 LPC GPIO block. It then preserves the
  physically validated v9.4 EDK2 rear-USB full-stack behavior.

  Persistent diagnostic status is written only to identify cold-boot progress. No OS name, UUID, serial, disk model or
  rear-port number is embedded. The only OS loader path is the standard
  removable-media path: \\EFI\\BOOT\\BOOTX64.EFI.

  SPDX-License-Identifier: BSD-2-Clause
**/

#include <Uefi.h>
#include <Guid/GlobalVariable.h>

#include <Protocol/DevicePath.h>
#include <Protocol/DriverBinding.h>
#include <Protocol/LoadedImage.h>
#include <Protocol/PciIo.h>
#include <Protocol/SimpleFileSystem.h>

#include <Library/BaseMemoryLib.h>
#include <Library/DevicePathLib.h>
#include <Library/IoLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/PrintLib.h>
#include <Library/UefiApplicationEntryPoint.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiRuntimeServicesTableLib.h>

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

#define FRONT_EHCI_DEVICE_ID        0x3A3A
#define ICH10_AHCI_DEVICE_ID        0x3A22
#define ETRON_VENDOR_ID             0x1B6F
#define ETRON_EJ168_DEVICE_ID       0x7023

// Per-tier settling windows. SATA power-up starts before tier 1, so its spin-up
// overlaps the front/rear search instead of adding directly to boot latency.
#define FRONT_DISCOVERY_TRIES       20
#define REAR_DISCOVERY_TRIES        100
#define SATA_DISCOVERY_TRIES        200
#define DISCOVERY_STALL_US          100000
#define BINDING_PASSES              10
#define BINDING_STALL_US            100000
#define MAX_BOOT_VARIABLE_SIZE       (1024U * 1024U)

STATIC CHAR16 mBootPath[] = L"\\EFI\\BOOT\\BOOTX64.EFI";

extern CONST UINT8 XhciDxeBlob[];
extern CONST UINTN XhciDxeBlobSize;
extern CONST UINT8 UsbBusDxeBlob[];
extern CONST UINTN UsbBusDxeBlobSize;
extern CONST UINT8 UsbMassStorageDxeBlob[];
extern CONST UINTN UsbMassStorageDxeBlobSize;
extern CONST UINT8 DiskIoDxeBlob[];
extern CONST UINTN DiskIoDxeBlobSize;
extern CONST UINT8 PartitionDxeBlob[];
extern CONST UINTN PartitionDxeBlobSize;
extern CONST UINT8 EnglishDxeBlob[];
extern CONST UINTN EnglishDxeBlobSize;
extern CONST UINT8 FatDxeBlob[];
extern CONST UINTN FatDxeBlobSize;

typedef struct {
  EFI_HANDLE ImageHandle;
  EFI_DRIVER_BINDING_PROTOCOL *Binding;
} N3_DRIVER;

typedef struct {
  UINT32                   Attributes;
  UINT16                   FilePathListLength;
  EFI_DEVICE_PATH_PROTOCOL *FilePath;
  UINT8                    *OptionalData;
  UINTN                    OptionalDataSize;
} N3_BOOT_OPTION;

#define STATUS_STARTED          BIT0
#define STATUS_GPIO_OK          BIT1
#define STATUS_FRONT_CTRL       BIT2
#define STATUS_FRONT_FS         BIT3
#define STATUS_REAR_CTRL        BIT4
#define STATUS_REAR_STACK_OK    BIT5
#define STATUS_REAR_FS          BIT6
#define STATUS_SATA_CTRL        BIT7
#define STATUS_SATA_FS          BIT8
#define STATUS_CHAINLOAD        BIT9

STATIC EFI_GUID mStatusGuid = {
  0x7130B003, 0xA149, 0x4A55, {0xB7, 0x13, 0x4E, 0x33, 0x53, 0x54, 0x41, 0x54}
};
STATIC UINT32 mStatusBits;
STATIC BOOLEAN mPersistentDiagnostics;
STATIC BOOLEAN mValidationMode;

STATIC VOID MarkStatus (IN UINT32 Bit)
{
  UINT32 Attributes;
  CHAR16 *Name;

  mStatusBits |= Bit;
  Attributes = EFI_VARIABLE_BOOTSERVICE_ACCESS | EFI_VARIABLE_RUNTIME_ACCESS;
  if (mPersistentDiagnostics) {
    Attributes |= EFI_VARIABLE_NON_VOLATILE;
    Name = L"DS713NativeBootN3Status";
  } else {
    Name = L"DS713NativeBootN3StatusVolatile";
  }
  (VOID)gRT->SetVariable (Name, &mStatusGuid, Attributes, sizeof (mStatusBits), &mStatusBits);
}

STATIC EFI_STATUS GuardValidationAttempt (VOID)
{
  EFI_STATUS Status;
  UINT8 Value;
  UINTN Size;

  mValidationMode = FALSE;
  mPersistentDiagnostics = FALSE;
  Value = 0;
  Size = sizeof (Value);
  Status = gRT->GetVariable (L"DS713NativeBootN3Debug", &mStatusGuid, NULL, &Size, &Value);
  if (EFI_ERROR (Status) || (Value != 1U)) {
    return EFI_SUCCESS;
  }
  mValidationMode = TRUE;
  mPersistentDiagnostics = TRUE;

  Value = 0;
  Size = sizeof (Value);
  Status = gRT->GetVariable (L"DS713NativeBootN3AttemptInProgress", &mStatusGuid, NULL, &Size, &Value);
  if (!EFI_ERROR (Status) && (Value == 1U)) {
    (VOID)gRT->SetVariable (L"DS713NativeBootN3AttemptInProgress", &mStatusGuid, 0, 0, NULL);
    return EFI_ALREADY_STARTED;
  }

  Value = 1;
  Status = gRT->SetVariable (
                  L"DS713NativeBootN3AttemptInProgress",
                  &mStatusGuid,
                  EFI_VARIABLE_NON_VOLATILE | EFI_VARIABLE_BOOTSERVICE_ACCESS | EFI_VARIABLE_RUNTIME_ACCESS,
                  sizeof (Value),
                  &Value
                  );
  if (EFI_ERROR (Status)) {
    return Status;
  }
  (VOID)gBS->SetWatchdogTimer (90, 0, 0, NULL);
  return EFI_SUCCESS;
}

STATIC VOID ClearValidationAttempt (VOID)
{
  if (mValidationMode) {
    (VOID)gRT->SetVariable (L"DS713NativeBootN3AttemptInProgress", &mStatusGuid, 0, 0, NULL);
    (VOID)gBS->SetWatchdogTimer (0, 0, 0, NULL);
  }
}

STATIC EFI_STATUS GuardSingleAttempt (VOID)
{
  EFI_STATUS Status;
  UINT8 Attempted;
  UINTN Size;
  Attempted = 0;
  Size = sizeof (Attempted);
  Status = gRT->GetVariable (L"DS713NativeBootAttempted", &mStatusGuid, NULL, &Size, &Attempted);
  if (!EFI_ERROR (Status) && Attempted == 1) {
    return EFI_ALREADY_STARTED;
  }
  Attempted = 1;
  return gRT->SetVariable (L"DS713NativeBootAttempted", &mStatusGuid,
    EFI_VARIABLE_BOOTSERVICE_ACCESS, sizeof (Attempted), &Attempted);
}

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
FindPciById (
  IN UINT16 Vid,
  IN UINT16 Did,
  OUT EFI_HANDLE *Match
  )
{
  EFI_STATUS          Status;
  EFI_HANDLE          *Handles;
  UINTN               HandleCount;
  UINTN               Index;
  EFI_PCI_IO_PROTOCOL *PciIo;
  UINT32              Id;

  if (Match == NULL) {
    return EFI_INVALID_PARAMETER;
  }
  *Match = NULL;
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
    Status = PciIo->Pci.Read (PciIo, EfiPciIoWidthUint32, 0, 1, &Id);
    if (EFI_ERROR (Status)) {
      continue;
    }
    if (((UINT16)(Id & 0xFFFFU) == Vid) && ((UINT16)(Id >> 16) == Did)) {
      *Match = Handles[Index];
      break;
    }
  }

  if (Handles != NULL) {
    FreePool (Handles);
  }
  return (*Match != NULL) ? EFI_SUCCESS : EFI_NOT_FOUND;
}

STATIC
EFI_STATUS
FindEtron (
  OUT EFI_HANDLE *Etron
  )
{
  return FindPciById (ETRON_VENDOR_ID, ETRON_EJ168_DEVICE_ID, Etron);
}

STATIC
EFI_STATUS
LoadEmbeddedDriver (
  IN EFI_HANDLE ParentImage,
  IN CONST UINT8 *Blob,
  IN UINTN BlobSize,
  IN BOOLEAN NeedBinding,
  OUT N3_DRIVER *Driver
  )
{
  EFI_STATUS Status;

  if ((Blob == NULL) || (BlobSize == 0) || (Driver == NULL)) {
    return EFI_INVALID_PARAMETER;
  }
  ZeroMem (Driver, sizeof (*Driver));
  Status = gBS->LoadImage (FALSE, ParentImage, NULL, (VOID *)(UINTN)Blob, BlobSize, &Driver->ImageHandle);
  if (EFI_ERROR (Status)) {
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
  Status = gBS->HandleProtocol (Driver->ImageHandle, &gEfiDriverBindingProtocolGuid, (VOID **)&Driver->Binding);
  return (EFI_ERROR (Status) || (Driver->Binding == NULL)) ? EFI_NOT_FOUND : EFI_SUCCESS;
}

STATIC
EFI_STATUS
StartBindingOnController (
  IN N3_DRIVER *Driver,
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
  IN N3_DRIVER *Driver,
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
GetVariableAlloc (
  IN CONST CHAR16 *Name,
  IN CONST EFI_GUID *Guid,
  OUT VOID **Buffer,
  OUT UINTN *VariableSize
  )
{
  EFI_STATUS Status;
  VOID       *Data;
  UINTN      Size;

  if ((Name == NULL) || (Guid == NULL) || (Buffer == NULL) || (VariableSize == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  *Buffer = NULL;
  *VariableSize = 0;
  Size = 0;
  Status = gRT->GetVariable ((CHAR16 *)Name, (EFI_GUID *)Guid, NULL, &Size, NULL);
  if (Status != EFI_BUFFER_TOO_SMALL) {
    return Status;
  }
  if ((Size == 0U) || (Size > MAX_BOOT_VARIABLE_SIZE)) {
    return EFI_BAD_BUFFER_SIZE;
  }

  Data = AllocatePool (Size);
  if (Data == NULL) {
    return EFI_OUT_OF_RESOURCES;
  }

  Status = gRT->GetVariable ((CHAR16 *)Name, (EFI_GUID *)Guid, NULL, &Size, Data);
  if (EFI_ERROR (Status)) {
    FreePool (Data);
    return Status;
  }

  *Buffer = Data;
  *VariableSize = Size;
  return EFI_SUCCESS;
}

STATIC
EFI_STATUS
ParseBootOptionVariable (
  IN VOID          *Buffer,
  IN UINTN         VariableSize,
  OUT N3_BOOT_OPTION *Option
  )
{
  CONST UINTN HeaderSize = sizeof (UINT32) + sizeof (UINT16);
  UINT8       *Bytes;
  UINTN       DescriptionBytes;
  UINTN       FilePathOffset;
  CHAR16      Character;
  BOOLEAN     DescriptionTerminated;

  if ((Buffer == NULL) || (Option == NULL)) {
    return EFI_INVALID_PARAMETER;
  }
  ZeroMem (Option, sizeof (*Option));
  if (VariableSize < HeaderSize + sizeof (CHAR16)) {
    return EFI_COMPROMISED_DATA;
  }

  Bytes = (UINT8 *)Buffer;
  CopyMem (&Option->Attributes, Bytes, sizeof (Option->Attributes));
  CopyMem (&Option->FilePathListLength, Bytes + sizeof (UINT32), sizeof (Option->FilePathListLength));

  DescriptionBytes = 0;
  DescriptionTerminated = FALSE;
  while ((HeaderSize + DescriptionBytes + sizeof (CHAR16)) <= VariableSize) {
    CopyMem (&Character, Bytes + HeaderSize + DescriptionBytes, sizeof (Character));
    DescriptionBytes += sizeof (CHAR16);
    if (Character == L'\0') {
      DescriptionTerminated = TRUE;
      break;
    }
  }
  if (!DescriptionTerminated) {
    return EFI_COMPROMISED_DATA;
  }

  FilePathOffset = HeaderSize + DescriptionBytes;
  if ((Option->FilePathListLength < sizeof (EFI_DEVICE_PATH_PROTOCOL)) ||
      (FilePathOffset > VariableSize) ||
      ((UINTN)Option->FilePathListLength > (VariableSize - FilePathOffset))) {
    return EFI_COMPROMISED_DATA;
  }

  Option->FilePath = (EFI_DEVICE_PATH_PROTOCOL *)(VOID *)(Bytes + FilePathOffset);
  if (!IsDevicePathValid (Option->FilePath, Option->FilePathListLength) ||
      (GetDevicePathSize (Option->FilePath) != Option->FilePathListLength)) {
    return EFI_COMPROMISED_DATA;
  }

  Option->OptionalData = Bytes + FilePathOffset + Option->FilePathListLength;
  Option->OptionalDataSize = VariableSize - FilePathOffset - Option->FilePathListLength;
  return EFI_SUCCESS;
}

STATIC
BOOLEAN
DevicePathIsBelowController (
  IN CONST EFI_DEVICE_PATH_PROTOCOL *Path,
  IN EFI_HANDLE Controller
  )
{
  EFI_DEVICE_PATH_PROTOCOL *ControllerPath;
  UINTN PathSize;
  UINTN ControllerSize;
  UINTN PrefixSize;

  if ((Path == NULL) || (Controller == NULL)) {
    return FALSE;
  }
  ControllerPath = DevicePathFromHandle (Controller);
  if (ControllerPath == NULL) {
    return FALSE;
  }
  PathSize = GetDevicePathSize (Path);
  ControllerSize = GetDevicePathSize (ControllerPath);
  if (ControllerSize <= sizeof (EFI_DEVICE_PATH_PROTOCOL)) {
    return FALSE;
  }
  PrefixSize = ControllerSize - sizeof (EFI_DEVICE_PATH_PROTOCOL);
  return (BOOLEAN)((PathSize > PrefixSize) &&
                   BytesEqual ((CONST UINT8 *)ControllerPath, (CONST UINT8 *)Path, PrefixSize));
}

STATIC
CONST HARDDRIVE_DEVICE_PATH *
FindHardDriveNode (
  IN CONST EFI_DEVICE_PATH_PROTOCOL *Path
  )
{
  CONST EFI_DEVICE_PATH_PROTOCOL *Node;

  if (Path == NULL) {
    return NULL;
  }
  Node = Path;
  while (!IsDevicePathEnd (Node)) {
    if ((DevicePathType (Node) == MEDIA_DEVICE_PATH) &&
        (DevicePathSubType (Node) == MEDIA_HARDDRIVE_DP) &&
        (DevicePathNodeLength (Node) == sizeof (HARDDRIVE_DEVICE_PATH))) {
      return (CONST HARDDRIVE_DEVICE_PATH *)(CONST VOID *)Node;
    }
    if (DevicePathNodeLength (Node) < sizeof (EFI_DEVICE_PATH_PROTOCOL)) {
      return NULL;
    }
    Node = NextDevicePathNode (Node);
  }
  return NULL;
}

STATIC
BOOLEAN
HardDriveNodesMatch (
  IN CONST HARDDRIVE_DEVICE_PATH *A,
  IN CONST HARDDRIVE_DEVICE_PATH *B
  )
{
  HARDDRIVE_DEVICE_PATH Left;
  HARDDRIVE_DEVICE_PATH Right;

  if ((A == NULL) || (B == NULL)) {
    return FALSE;
  }
  CopyMem (&Left, A, sizeof (Left));
  CopyMem (&Right, B, sizeof (Right));

  if ((Left.SignatureType != SIGNATURE_TYPE_GUID) &&
      (Left.SignatureType != SIGNATURE_TYPE_MBR) &&
      (Left.SignatureType != NO_DISK_SIGNATURE)) {
    return FALSE;
  }

  // Match EDK2 BmMatchPartitionDevicePathNode(): partition identity is the
  // partition number + MBR/signature type + full 16-byte signature.
  return (BOOLEAN)(
           (Left.PartitionNumber == Right.PartitionNumber) &&
           (Left.MBRType == Right.MBRType) &&
           (Left.SignatureType == Right.SignatureType) &&
           (CompareMem (Left.Signature, Right.Signature, sizeof (Left.Signature)) == 0)
           );
}

STATIC
EFI_STATUS
StartOsLoaderPath (
  IN EFI_HANDLE ParentImage,
  IN EFI_DEVICE_PATH_PROTOCOL *Path,
  IN VOID       *OptionalData,
  IN UINTN      OptionalDataSize,
  IN UINT16     BootOptionNumber,
  IN BOOLEAN    HasBootOptionNumber
  )
{
  EFI_STATUS                Status;
  EFI_HANDLE                Child;
  EFI_LOADED_IMAGE_PROTOCOL *LoadedImage;

  if (Path == NULL) {
    return EFI_INVALID_PARAMETER;
  }
  Child = NULL;
  LoadedImage = NULL;

  Status = gBS->LoadImage (TRUE, ParentImage, Path, NULL, 0, &Child);
  if (EFI_ERROR (Status)) {
    if ((Status == EFI_SECURITY_VIOLATION) && (Child != NULL)) {
      (VOID)gBS->UnloadImage (Child);
    }
    return Status;
  }

  Status = gBS->HandleProtocol (Child, &gEfiLoadedImageProtocolGuid, (VOID **)&LoadedImage);
  if (EFI_ERROR (Status) || (LoadedImage == NULL)) {
    (VOID)gBS->UnloadImage (Child);
    return EFI_LOAD_ERROR;
  }
  LoadedImage->LoadOptions = (OptionalDataSize == 0U) ? NULL : OptionalData;
  LoadedImage->LoadOptionsSize = (UINT32)OptionalDataSize;

  if (HasBootOptionNumber) {
    (VOID)gRT->SetVariable (
                L"BootCurrent",
                &gEfiGlobalVariableGuid,
                EFI_VARIABLE_BOOTSERVICE_ACCESS | EFI_VARIABLE_RUNTIME_ACCESS,
                sizeof (BootOptionNumber),
                &BootOptionNumber
                );
  }

  Status = gBS->SetWatchdogTimer (mValidationMode ? 90 : 300, 0, 0, NULL);
  if (EFI_ERROR (Status)) {
    (VOID)gBS->UnloadImage (Child);
    return Status;
  }

  MarkStatus (STATUS_CHAINLOAD);
  Status = gBS->StartImage (Child, NULL, NULL);

  // A successful OS hand-off never returns. If it does, remove our temporary
  // BootCurrent just like EDK2 does when a Boot#### execution returns.
  (VOID)gBS->SetWatchdogTimer (0, 0, 0, NULL);
  if (HasBootOptionNumber) {
    (VOID)gRT->SetVariable (L"BootCurrent", &gEfiGlobalVariableGuid, 0, 0, NULL);
  }
  (VOID)gBS->UnloadImage (Child);
  return EFI_ERROR (Status) ? Status : EFI_ABORTED;
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

  Path = FileDevicePath (FileSystem, mBootPath);
  if (Path == NULL) {
    return EFI_OUT_OF_RESOURCES;
  }
  Status = StartOsLoaderPath (ParentImage, Path, NULL, 0, 0, FALSE);
  FreePool (Path);
  return Status;
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
TryHdBootOptionForController (
  IN EFI_HANDLE ParentImage,
  IN EFI_HANDLE Controller,
  IN N3_BOOT_OPTION *Option,
  IN UINT16 BootOptionNumber,
  IN UINT32 FsStatusBit
  )
{
  EFI_STATUS Status;
  EFI_HANDLE *Handles;
  UINTN HandleCount;
  UINTN Index;
  CONST HARDDRIVE_DEVICE_PATH *BootHd;
  CONST HARDDRIVE_DEVICE_PATH *FsHd;
  EFI_DEVICE_PATH_PROTOCOL *FsPath;
  EFI_DEVICE_PATH_PROTOCOL *Tail;
  EFI_DEVICE_PATH_PROTOCOL *Expanded;

  BootHd = FindHardDriveNode (Option->FilePath);
  if ((BootHd == NULL) ||
      (DevicePathType ((EFI_DEVICE_PATH_PROTOCOL *)(VOID *)Option->FilePath) != MEDIA_DEVICE_PATH) ||
      (DevicePathSubType ((EFI_DEVICE_PATH_PROTOCOL *)(VOID *)Option->FilePath) != MEDIA_HARDDRIVE_DP)) {
    return EFI_NOT_FOUND;
  }

  Handles = NULL;
  HandleCount = 0;
  Status = gBS->LocateHandleBuffer (ByProtocol, &gEfiSimpleFileSystemProtocolGuid, NULL, &HandleCount, &Handles);
  if (EFI_ERROR (Status)) {
    return Status;
  }

  for (Index = 0; Index < HandleCount; ++Index) {
    if (!IsBelowController (Handles[Index], Controller)) {
      continue;
    }
    FsPath = DevicePathFromHandle (Handles[Index]);
    FsHd = FindHardDriveNode (FsPath);
    if (!HardDriveNodesMatch (BootHd, FsHd)) {
      continue;
    }
    if (FsStatusBit != 0U) {
      MarkStatus (FsStatusBit);
    }

    Tail = NextDevicePathNode ((EFI_DEVICE_PATH_PROTOCOL *)(VOID *)BootHd);
    if (IsDevicePathEnd (Tail)) {
      Expanded = FileDevicePath (Handles[Index], mBootPath);
    } else {
      Expanded = AppendDevicePath (FsPath, Tail);
    }
    if (Expanded == NULL) {
      continue;
    }

    Status = StartOsLoaderPath (
               ParentImage,
               Expanded,
               Option->OptionalData,
               Option->OptionalDataSize,
               BootOptionNumber,
               TRUE
               );
    FreePool (Expanded);
    if (!CandidateFailureIsLocal (Status)) {
      FreePool (Handles);
      return Status;
    }
  }

  FreePool (Handles);
  return EFI_NOT_FOUND;
}

STATIC
EFI_STATUS
TryFilePathBootOptionForController (
  IN EFI_HANDLE ParentImage,
  IN EFI_HANDLE Controller,
  IN N3_BOOT_OPTION *Option,
  IN UINT16 BootOptionNumber,
  IN UINT32 FsStatusBit
  )
{
  EFI_STATUS Status;
  EFI_HANDLE *Handles;
  UINTN HandleCount;
  UINTN Index;
  EFI_DEVICE_PATH_PROTOCOL *FsPath;
  EFI_DEVICE_PATH_PROTOCOL *Expanded;

  if ((DevicePathType (Option->FilePath) != MEDIA_DEVICE_PATH) ||
      (DevicePathSubType (Option->FilePath) != MEDIA_FILEPATH_DP)) {
    return EFI_NOT_FOUND;
  }

  Handles = NULL;
  HandleCount = 0;
  Status = gBS->LocateHandleBuffer (ByProtocol, &gEfiSimpleFileSystemProtocolGuid, NULL, &HandleCount, &Handles);
  if (EFI_ERROR (Status)) {
    return Status;
  }

  for (Index = 0; Index < HandleCount; ++Index) {
    if (!IsBelowController (Handles[Index], Controller)) {
      continue;
    }
    FsPath = DevicePathFromHandle (Handles[Index]);
    Expanded = AppendDevicePath (FsPath, Option->FilePath);
    if (Expanded == NULL) {
      continue;
    }
    if (FsStatusBit != 0U) {
      MarkStatus (FsStatusBit);
    }
    Status = StartOsLoaderPath (ParentImage, Expanded, Option->OptionalData, Option->OptionalDataSize,
                                BootOptionNumber, TRUE);
    FreePool (Expanded);
    if (!CandidateFailureIsLocal (Status)) {
      FreePool (Handles);
      return Status;
    }
  }

  FreePool (Handles);
  return EFI_NOT_FOUND;
}

STATIC
EFI_STATUS
TryOneBootOptionForController (
  IN EFI_HANDLE ParentImage,
  IN EFI_HANDLE Controller,
  IN N3_BOOT_OPTION *Option,
  IN UINT16 BootOptionNumber,
  IN UINT32 FsStatusBit
  )
{
  EFI_STATUS Status;

  if ((Option == NULL) || ((Option->Attributes & LOAD_OPTION_ACTIVE) == 0U)) {
    return EFI_NOT_FOUND;
  }

  if ((DevicePathType (Option->FilePath) == MEDIA_DEVICE_PATH) &&
      (DevicePathSubType (Option->FilePath) == MEDIA_HARDDRIVE_DP)) {
    return TryHdBootOptionForController (ParentImage, Controller, Option, BootOptionNumber, FsStatusBit);
  }

  if ((DevicePathType (Option->FilePath) == MEDIA_DEVICE_PATH) &&
      (DevicePathSubType (Option->FilePath) == MEDIA_FILEPATH_DP)) {
    return TryFilePathBootOptionForController (ParentImage, Controller, Option, BootOptionNumber, FsStatusBit);
  }

  if (!DevicePathIsBelowController (Option->FilePath, Controller)) {
    return EFI_NOT_FOUND;
  }

  if (FsStatusBit != 0U) {
    MarkStatus (FsStatusBit);
  }
  Status = StartOsLoaderPath (ParentImage, Option->FilePath, Option->OptionalData, Option->OptionalDataSize,
                              BootOptionNumber, TRUE);
  return CandidateFailureIsLocal (Status) ? EFI_NOT_FOUND : Status;
}

STATIC
EFI_STATUS
TryBootOptionsForController (
  IN EFI_HANDLE ParentImage,
  IN EFI_HANDLE Controller,
  IN UINT32 FsStatusBit
  )
{
  EFI_STATUS Status;
  VOID       *BootOrderBuffer;
  UINTN      BootOrderSize;
  UINT8      *BootOrderBytes;
  UINTN      Index;
  UINT16     BootOptionNumber;
  CHAR16     VariableName[9];
  VOID       *VariableBuffer;
  UINTN      VariableSize;
  N3_BOOT_OPTION Option;

  BootOrderBuffer = NULL;
  BootOrderSize = 0;
  Status = GetVariableAlloc (L"BootOrder", &gEfiGlobalVariableGuid, &BootOrderBuffer, &BootOrderSize);
  if (EFI_ERROR (Status)) {
    return EFI_NOT_FOUND;
  }
  if ((BootOrderSize == 0U) || ((BootOrderSize % sizeof (UINT16)) != 0U)) {
    FreePool (BootOrderBuffer);
    return EFI_NOT_FOUND;
  }

  BootOrderBytes = (UINT8 *)BootOrderBuffer;
  for (Index = 0; Index < BootOrderSize / sizeof (UINT16); ++Index) {
    CopyMem (&BootOptionNumber, BootOrderBytes + (Index * sizeof (UINT16)), sizeof (BootOptionNumber));
    UnicodeSPrint (VariableName, sizeof (VariableName), L"Boot%04x", BootOptionNumber);

    VariableBuffer = NULL;
    VariableSize = 0;
    Status = GetVariableAlloc (VariableName, &gEfiGlobalVariableGuid, &VariableBuffer, &VariableSize);
    if (EFI_ERROR (Status)) {
      continue;
    }

    Status = ParseBootOptionVariable (VariableBuffer, VariableSize, &Option);
    if (!EFI_ERROR (Status) && ((Option.Attributes & LOAD_OPTION_ACTIVE) != 0U)) {
      Status = TryOneBootOptionForController (
                 ParentImage,
                 Controller,
                 &Option,
                 BootOptionNumber,
                 FsStatusBit
                 );
      if (!CandidateFailureIsLocal (Status) && (Status != EFI_NOT_FOUND)) {
        FreePool (VariableBuffer);
        FreePool (BootOrderBuffer);
        return Status;
      }
    }
    FreePool (VariableBuffer);
  }

  FreePool (BootOrderBuffer);
  return EFI_NOT_FOUND;
}

STATIC
EFI_STATUS
TryControllerFilesystems (
  IN EFI_HANDLE ParentImage,
  IN EFI_HANDLE Controller,
  IN UINT32     FsStatusBit
  )
{
  EFI_STATUS Status;
  EFI_HANDLE *Handles;
  UINTN HandleCount;
  UINTN Index;

  if (Controller == NULL) {
    return EFI_INVALID_PARAMETER;
  }
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
    if (!IsBelowController (Handles[Index], Controller)) {
      continue;
    }

    if (FsStatusBit != 0U) {
      MarkStatus (FsStatusBit);
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
TryRearFilesystems (
  IN EFI_HANDLE ParentImage,
  IN EFI_HANDLE Etron
  )
{
  return TryControllerFilesystems (ParentImage, Etron, STATUS_REAR_FS);
}

STATIC
EFI_STATUS
LoadFullStack (
  IN EFI_HANDLE ParentImage,
  IN EFI_HANDLE Etron
  )
{
  EFI_STATUS Status;
  N3_DRIVER Xhci;
  N3_DRIVER UsbBus;
  N3_DRIVER UsbMass;
  N3_DRIVER DiskIo;
  N3_DRIVER Partition;
  N3_DRIVER English;
  N3_DRIVER Fat;
  BOOLEAN Started;
  UINTN Pass;
  UINTN Progress;
  UINTN Count;

  Status = LoadEmbeddedDriver (ParentImage, XhciDxeBlob, XhciDxeBlobSize, TRUE, &Xhci);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  Status = LoadEmbeddedDriver (ParentImage, UsbBusDxeBlob, UsbBusDxeBlobSize, TRUE, &UsbBus);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  Status = LoadEmbeddedDriver (ParentImage, UsbMassStorageDxeBlob, UsbMassStorageDxeBlobSize, TRUE, &UsbMass);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  Status = LoadEmbeddedDriver (ParentImage, DiskIoDxeBlob, DiskIoDxeBlobSize, TRUE, &DiskIo);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  Status = LoadEmbeddedDriver (ParentImage, PartitionDxeBlob, PartitionDxeBlobSize, TRUE, &Partition);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  Status = LoadEmbeddedDriver (ParentImage, EnglishDxeBlob, EnglishDxeBlobSize, FALSE, &English);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  Status = LoadEmbeddedDriver (ParentImage, FatDxeBlob, FatDxeBlobSize, TRUE, &Fat);
  if (EFI_ERROR (Status)) {
    return Status;
  }

  Started = FALSE;
  Status = StartBindingOnController (&Xhci, Etron, &Started);
  if (EFI_ERROR (Status)) {
    return Status;
  }

  // Let the UEFI core recursively connect everything it can with the now-loaded
  // stack, then retain the v9.5 manual binding passes as the proven compatibility path.
  (VOID)gBS->ConnectController (Etron, NULL, NULL, TRUE);

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

STATIC
EFI_STATUS
TryFrontUsb (
  IN EFI_HANDLE ParentImage
  )
{
  EFI_STATUS Status;
  EFI_HANDLE Front;
  UINTN Try;

  Front = NULL;
  Status = FindPciById (INTEL_VENDOR_ID, FRONT_EHCI_DEVICE_ID, &Front);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  MarkStatus (STATUS_FRONT_CTRL);

  for (Try = 0; Try < FRONT_DISCOVERY_TRIES; ++Try) {
    // Repeated ConnectController is non-destructive; it gives late USB enumeration
    // another chance without resetting or disconnecting the bus.
    (VOID)gBS->ConnectController (Front, NULL, NULL, TRUE);
    Status = TryBootOptionsForController (ParentImage, Front, STATUS_FRONT_FS);
    if (Status != EFI_NOT_FOUND) {
      return Status;
    }
    Status = TryControllerFilesystems (ParentImage, Front, STATUS_FRONT_FS);
    if (Status != EFI_NOT_FOUND) {
      return Status;
    }
    if (Try + 1U < FRONT_DISCOVERY_TRIES) {
      gBS->Stall (DISCOVERY_STALL_US);
    }
  }
  return EFI_NOT_FOUND;
}

STATIC
EFI_STATUS
TryRearUsb (
  IN EFI_HANDLE ParentImage
  )
{
  EFI_STATUS Status;
  EFI_HANDLE Etron;
  UINTN Try;

  Etron = NULL;
  Status = FindEtron (&Etron);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  MarkStatus (STATUS_REAR_CTRL);

  Status = LoadFullStack (ParentImage, Etron);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  MarkStatus (STATUS_REAR_STACK_OK);

  for (Try = 0; Try < REAR_DISCOVERY_TRIES; ++Try) {
    (VOID)gBS->ConnectController (Etron, NULL, NULL, TRUE);
    Status = TryBootOptionsForController (ParentImage, Etron, STATUS_REAR_FS);
    if (Status != EFI_NOT_FOUND) {
      return Status;
    }
    Status = TryRearFilesystems (ParentImage, Etron);
    if (Status != EFI_NOT_FOUND) {
      return Status;
    }
    if (Try + 1U < REAR_DISCOVERY_TRIES) {
      gBS->Stall (DISCOVERY_STALL_US);
    }
  }
  return EFI_NOT_FOUND;
}

STATIC
EFI_STATUS
TryInternalSata (
  IN EFI_HANDLE ParentImage
  )
{
  EFI_STATUS Status;
  EFI_HANDLE Ahci;
  UINTN Try;

  Ahci = NULL;
  Status = FindPciById (INTEL_VENDOR_ID, ICH10_AHCI_DEVICE_ID, &Ahci);
  if (EFI_ERROR (Status)) {
    return Status;
  }
  MarkStatus (STATUS_SATA_CTRL);

  for (Try = 0; Try < SATA_DISCOVERY_TRIES; ++Try) {
    // Stock firmware already contains SataController/AtaBus/AhciDxe. Connect it
    // recursively; never disconnect/reset a live SATA controller.
    (VOID)gBS->ConnectController (Ahci, NULL, NULL, TRUE);
    Status = TryBootOptionsForController (ParentImage, Ahci, STATUS_SATA_FS);
    if (Status != EFI_NOT_FOUND) {
      return Status;
    }
    Status = TryControllerFilesystems (ParentImage, Ahci, STATUS_SATA_FS);
    if (Status != EFI_NOT_FOUND) {
      return Status;
    }
    if (Try + 1U < SATA_DISCOVERY_TRIES) {
      gBS->Stall (DISCOVERY_STALL_US);
    }
  }
  return EFI_NOT_FOUND;
}

EFI_STATUS
EFIAPI
UefiMain (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS Status;

  (VOID)SystemTable;

  (VOID)gBS->SetWatchdogTimer (0, 0, 0, NULL);
  Status = GuardValidationAttempt ();
  if (Status == EFI_ALREADY_STARTED) {
    return EFI_ABORTED;
  }
  if (EFI_ERROR (Status)) {
    return Status;
  }
  Status = GuardSingleAttempt ();
  if (Status == EFI_ALREADY_STARTED) {
    return EFI_ABORTED;
  }
  if (EFI_ERROR (Status)) {
    return Status;
  }

  mStatusBits = 0;
  MarkStatus (STATUS_STARTED);

  // Power SATA immediately so spin-up overlaps higher-priority front/rear probing.
  // Fail-open: GPIO failure must not prevent booting a valid USB device.
  Status = EnableInternalHddPower ();
  if (!EFI_ERROR (Status)) {
    MarkStatus (STATUS_GPIO_OK);
  }

  // Strict physical policy: front USB -> rear Etron USB -> internal SATA.
  // A successful OS handoff never returns. Any failed candidate/tier falls through.
  Status = TryFrontUsb (ImageHandle);
  (VOID)Status;

  Status = TryRearUsb (ImageHandle);
  (VOID)Status;

  Status = TryInternalSata (ImageHandle);
  (VOID)Status;

  ClearValidationAttempt ();
  return EFI_NOT_FOUND;
}
