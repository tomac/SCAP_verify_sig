#!/usr/bin/perl -w
# Verify an RSA2048 digital signature in Apple SCAP (Secure Capsule) files
# Based on the work from Trammell Hudson in Thunderstrike
# Check his project at https://trmm.net/Thunderstrike_31c3
#
# I've just added some minor changes to support other SCAP files that could be
# bigger or smaller
#
# Important information:
# - The first 16 bytes represent the GUID 3b6686bd-0d76-4030-b70eb5519e2fc5a0
#   (EFI_CAPSULE_HEADER)
# - Header size is at offset 0x10
# - Total SCAP file size is at offset 0x50
# - Total Firmware Volume size is at offset 0x70
# - The last 0x220 bytes include:
#   - GUID aa7717414-c616-4977-9420844712a735bf (EFI_CERT_TYPE_RSA2048_SHA256_GUID)
#   - 2048 RSA Public key
#   - SHA256 signature
#
use strict;
use Crypt::OpenSSL::RSA;
use Crypt::OpenSSL::Bignum;

# EFI_CERT_TYPE_RSA2048_SHA256_GUID
my $guid = qq{\x14\x74\x71\xA7\x16\xC6\x77\x49\x94\x20\x84\x47\x12\xA7\x35\xBF};

my $scap = do { undef $/ ; <> };
my $volume_size = substr($scap, 0x70, 0x8);
printf("Volume size: 0x%x\n", unpack("VH8", $volume_size));

# Find EFI_CERT_TYPE_RSA2048_SHA256_GUID
my $start = index($scap, $guid);
printf("position: 0x%x\n", $start);

my $fvh = substr($scap, 0x50, unpack("VH8", $volume_size));
my $pub = reverse substr($scap, $start + 0x10, 0x100); # Switch from little- to big-endian
my $sig = reverse substr($scap, $start + 0x110, 0x100); # (Thanks, Viktor!)

my $n = Crypt::OpenSSL::Bignum->new_from_bin($pub);
my $e = Crypt::OpenSSL::Bignum->new_from_decimal("65537");
my $rsa = Crypt::OpenSSL::RSA->new_key_from_parameters($n,$e);
$rsa->use_sha256_hash();

print "Signature ok!\n" if $rsa->verify($fvh, $sig);
print $rsa->get_public_key_string();