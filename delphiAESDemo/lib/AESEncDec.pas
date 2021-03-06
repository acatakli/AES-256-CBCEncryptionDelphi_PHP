//Code Owner: https://stackoverflow.com/a/43591761

unit AESencdec;

interface

uses DCPcrypt2, DCPsha256, DCPblockciphers, DCPrijndael, System.SysUtils;

type
  TChainingMode = (cmCBC, cmCFB8bit, cmCFBblock, cmOFB, cmCTR, cmECB);
  TPaddingMode = (pmZeroPadding, pmANSIX923, pmISO10126, pmISO7816, pmPKCS7,
    pmRandomPadding);

  TAESEncDec = class
  public
    procedure BytePadding(var Data: TBytes; BlockSize: integer;
      PaddingMode: TPaddingMode);
    function EncryptAES(const Data: TBytes; const Key: TBytes; KeySize: integer;
      const InitVector: TBytes; ChainingMode: TChainingMode;
      PaddingMode: TPaddingMode): TBytes;
  end;

implementation

procedure TAESEncDec.BytePadding(var Data: TBytes; BlockSize: integer;
  PaddingMode: TPaddingMode);
// Supports: ANSI X.923, ISO 10126, ISO 7816, PKCS7, zero padding and random padding
var
  I, DataBlocks, DataLength, PaddingStart, PaddingCount: integer;
begin
  BlockSize := BlockSize div 8; // convert bits to bytes
  // Zero and Random padding do not use end-markers, so if Length(Data) is a multiple of BlockSize, no padding is needed
  if PaddingMode in [pmZeroPadding, pmRandomPadding] then
    if Length(Data) mod BlockSize = 0 then
      Exit;
  DataBlocks := (Length(Data) div BlockSize) + 1;
  DataLength := DataBlocks * BlockSize;
  PaddingCount := DataLength - Length(Data);
  // ANSIX923, ISO10126 and PKCS7 store the padding length in a 1 byte end-marker, so any padding length > $FF is not supported
  if PaddingMode in [pmANSIX923, pmISO10126, pmPKCS7] then
    if PaddingCount > $FF then
      Exit;
  PaddingStart := Length(Data);
  SetLength(Data, DataLength);
  case PaddingMode of
    pmZeroPadding, pmANSIX923, pmISO7816: // fill with $00 bytes
      FillChar(Data[PaddingStart], PaddingCount, 0);
    pmPKCS7: // fill with PaddingCount bytes
      FillChar(Data[PaddingStart], PaddingCount, PaddingCount);
    pmRandomPadding, pmISO10126: // fill with random bytes
      for I := PaddingStart to DataLength - 1 do
        Data[I] := Random($FF);
  end;
  case PaddingMode of
    pmANSIX923, pmISO10126:
      Data[DataLength - 1] := PaddingCount;
      // set end-marker with number of bytes added
    pmISO7816:
      Data[PaddingStart] := $80; // set fixed end-markder $80
  end;
end;

function TAESEncDec.EncryptAES(const Data: TBytes; const Key: TBytes;
  KeySize: integer; const InitVector: TBytes; ChainingMode: TChainingMode;
  PaddingMode: TPaddingMode): TBytes;
var
  Cipher: TDCP_rijndael;
begin
  Cipher := TDCP_rijndael.Create(nil);
  try
    Cipher.Init(Key[0], KeySize, @InitVector[0]);
    // Copy Data => Crypt
    Result := Copy(Data, 0, Length(Data));
    // Padd Crypt to required length (for Block based algorithms)
    if ChainingMode in [cmCBC, cmECB] then
      BytePadding(Result, Cipher.BlockSize, PaddingMode);
    // Encrypt Crypt using the algorithm specified in ChainingMode
    case ChainingMode of
      cmCBC:
        Cipher.EncryptCBC(Result[0], Result[0], Length(Result));
      cmCFB8bit:
        Cipher.EncryptCFB8bit(Result[0], Result[0], Length(Result));
      cmCFBblock:
        Cipher.EncryptCFBblock(Result[0], Result[0], Length(Result));
      cmOFB:
        Cipher.EncryptOFB(Result[0], Result[0], Length(Result));
      cmCTR:
        Cipher.EncryptCTR(Result[0], Result[0], Length(Result));
      cmECB:
        Cipher.EncryptECB(Result[0], Result[0]);
    end;

  finally
    Cipher.Free;
  end;
end;

end.
