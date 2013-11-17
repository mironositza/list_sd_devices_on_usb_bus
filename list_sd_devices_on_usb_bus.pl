#!/usr/bin/perl -w
# ============================================================================
# List the devices on a USB bus (on Linux) by examining the /sys filesystem.
# Check which USB device is associated to a SCSI block device.
# 
# Latest version at https://github.com/dtonhofer/list_sd_devices_on_usb_bus
# ============================================================================
# Distributed under the MIT License, see http://opensource.org/licenses/MIT
# 
# Copyright (c) 2013
# David Tonhofer
# 14, rue Aldringen
# L-1118 Luxembourg
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# ============================================================================

use 5.012; # so readdir assigns to $_ in a lone while test
use File::Slurp; # yum install perl-File-Slurp.noarch

my $TEXT          = "text";
my $ORIG          = "orig";
my $DEVICE_DIR    = "devicedir";
my $SD_DEVICE     = "sddevice";
my $SD_DEVICE_DIR = "sddevicedir";

# List devices by checking "sys" filesystem; the retrieved stuff will
# be put into a sortable structure, which is a "tree of hashes", the
# root of which is "root"

my $whereUsb       = "/sys/bus/usb/devices";
my $whereBlockDevs = "/sys/block";

my $usbTree      = slurpUsbDevices($whereUsb);
my $blockDevHash = slurpBlockDevices($whereBlockDevs);

# for my $bde (sort keys %$blockDevHash) {
#   print "$bde --> $$blockDevHash{$bde}\n"
# }

assignBlockDevicesToUsbTreeEntries($usbTree,$blockDevHash);
printUsbTreeEntries($whereUsb,$usbTree,1,1);

# ===
# This reads information about the USB devices visible on the system (in directory "$where")
# ===

sub slurpUsbDevices {
   my($where) = @_;
   my $root = {};
   #
   # So let's open the directory
   #
   my $success = opendir(my $dh,$where);
   if (!$success) {
      print STDERR "Could not open directory '$where' -- exiting: $!\n";
      exit 1
   }
   #
   # Read directory entries one by one; see the Linux USB FAQ at
   # http://www.linux-usb.org/FAQ.html for the format of the filenames
   # (actually symlinks) in that directory
   #
   while (my $curEntry = readdir($dh)) {
      #
      # Skip the directory entries and the USB controller entries
      #
      if ($curEntry eq "." || $curEntry eq ".." || $curEntry =~ /^usb\d+$/) {
         next      
      }
      #
      # Otherwise, take the string B-P1.P2.P3:CONFIG:IF apart; interprete the
      # elements as numbers not as strings
      #
      if ($curEntry =~ /^(\d+)-([\d\.]+)(:.*)?$/) {
         my $bus        = $1 * 1;
         my @portPath   = (split('\.',$2)); @portPath = map { $_ * 1 } @portPath;
         my $suffix     = $3;
         my $config;
         my $interface;
         my $discard    = 0;
         if ($suffix) {
            if ($suffix =~ /^:(\d+)\.(\d+)$/) {
               $config    = $1 * 1;
               $interface = $2 * 1;
            }
            else {
               print STDERR "Found nonempty suffix '$suffix' which cannot be parsed in entry '$curEntry' -- discarding entry\n";
               $discard = 1
            }
         }
         if (!$discard) {
            recomposeAndVerify($curEntry,$bus,\@portPath,$config,$interface);
            #
            # Update "root" tree: bus level
            #
            my $curKey = "bus:$bus";
            if (!(exists $$root{$curKey})) {
               $$root{$curKey} = {}
            } 
            my $curHash = $$root{$curKey};
            #
            # Update "root" tree: port level
            #
            for my $curPort (@portPath) {
               $curKey = "port:$curPort";
               if (!(exists $$curHash{$curKey})) {
                  $$curHash{$curKey} = {}
               }             
               $curHash = $$curHash{$curKey};
            }
            #
            # Update "root" tree; config and interface level
            #
            if (defined($config)) {
               $curKey = "config:$config";
               if (!(exists $$curHash{$curKey})) {
                  $$curHash{$curKey} = {}
               }             
               $curHash = $$curHash{$curKey};
               $curKey = "if:$interface";
               if (!(exists $$curHash{$curKey})) {
                  $$curHash{$curKey} = {}
               }            
               else {
                  print STDERR "Naming clash; already have an entry for '$curEntry'\n";
               } 
               $curHash = $$curHash{$curKey};
            }
            #
            # Add a text into $curHash under a key that will always come first when one sorts the
            # hash trivially - by using the key ""
            #                 
            my $jointure = join(' -> port ',@portPath); 
            my $text = "bus $bus -> port $jointure";
            if (defined($config)) {
               $text .= " -> config $config -> interface $interface"
            }
            if (exists $$curHash{""}) {
               print STDERR "Naming clash; already have a text entry for '$curEntry'\n";
            } 
            #
            # The "curEntry" is a symlink to points to some entry under /sys/devices - resolve!
            #
            my $theLink = $where . "/" . $curEntry;
            my $theDir  = `/bin/readlink -e '${theLink}'`;
            if ($? != 0) {
               print STDERR "Could not readlink the link '$theLink' -- exiting\n";
               exit 1
            }
            chomp $theDir;
            if (! -d $theDir) {
               print STDERR "The link '$theLink' does not point to a proper directory '$theDir' -- exiting\n";
               exit 1
            }      
            $$curHash{""} = { $TEXT => $text, $ORIG => $curEntry, $DEVICE_DIR => $theDir }
         }
      }
      else {
         print STDERR "Cannot parse entry '$curEntry' -- discarding entry\n"
      }
   }
   closedir($dh);
   return $root
}

# ===
# This reads information about the block devices visible on the system (in directory "$where")
# ===

sub slurpBlockDevices {
   my($where) = @_;
   my $blockDevHash = {}; # list block devices by their path under "devices"
   #
   # So let's open the directory
   #
   my $success = opendir(my $dh,$where);
   if (!$success) {
      print STDERR "Could not open directory '$where' -- exiting: $!\n";
      exit 1
   }
   #
   # Read directory entries one by one
   #
   while (my $curEntry = readdir($dh)) {
      #
      # Skip the directory entries and anything that isn't named like a SCSI block device
      #
      if ($curEntry eq "." || $curEntry eq ".." || !($curEntry =~ /^sd[a-z]$/)) {
         next      
      }
      #
      # So this is actually a link to a directory, which we now get using "readlink"
      #
      my $theLink = $where . "/" . $curEntry;
      my $theDir  = `/bin/readlink -e '${theLink}'`;
      if ($? != 0) {
         print STDERR "Could not readlink the link '$theLink' -- exiting\n";
         exit 1
      }
      chomp $theDir;
      if (! -d $theDir) {
         print STDERR "The link '$theLink' does not point to a proper directory '$theDir' -- exiting\n";
         exit 1
      }
      if ($$blockDevHash{$theDir}) {
         print STDERR "The path '$theDir' has already been seen! Previously for '" . $$blockDevHash{$theDir} . "' and now for '${curEntry}' -- exiting\n";
      }
      $$blockDevHash{$theDir} = $curEntry
   }
   closedir($dh);
   return $blockDevHash
}

# === 
# Print the "USB tree", with additional information obtained by looking for more files
# ===

sub printUsbTreeEntries {
   my ($where,$curHash,$curBus,$prevBus) = @_;
   for my $curKey (sort keys %$curHash) {
      #
      # For prettyprinting: Add a separator when the next bus listing starts
      #
      if ($curKey =~ /^bus:(\d+)$/) {
         $curBus = $1 * 1;
         if ($curBus != $prevBus) {
            print "\n--\n\n";
            $prevBus = $curBus
         }         
      }
      #
      # If the key is "" this is an actual examinable entry; otherwise do a recursive call
      #
      if ($curKey eq "") {
         my $textHash = $$curHash{""};
         my $textOut = buildOutputText($textHash);
         print "$textOut\n"
      }
      else {
         printUsbTreeEntries($where,$$curHash{$curKey},$curBus,$curBus)
      }
   }
}

# ===
# Additional USB info
# ===

sub buildOutputText {
   my($textHash) = @_;
   my $indent = "     ";
   my $originalString = $$textHash{$ORIG};
   my $text           = $$textHash{$TEXT};
   my $theDir         = $$textHash{$DEVICE_DIR};
   my $blockDev       = $$textHash{$SD_DEVICE};
   my $blockDevDir    = $$textHash{$SD_DEVICE_DIR};
   #
   # There may be additional info in "theDir"
   # See also: https://www.kernel.org/doc/htmldocs/usb/API-struct-usb-device.html
   #   
   my ($dev,$product,$idProduct,$idVendor,$idCode,$version,$manuf,$serial);
   if (-f "$theDir/dev")          { $dev       = read_file("$theDir/dev"); chomp $dev }
   if (-f "$theDir/product")      { $product   = read_file("$theDir/product"); chomp $product }
   if (-f "$theDir/idProduct")    { $idProduct = read_file("$theDir/idProduct"); chomp $idProduct }
   if (-f "$theDir/idVendor")     { $idVendor  = read_file("$theDir/idVendor"); chomp $idVendor }
   if (-f "$theDir/version")      { $version   = read_file("$theDir/version"); chomp $version }
   if (-f "$theDir/manufacturer") { $manuf     = read_file("$theDir/manufacturer"); chomp $manuf }
   if (-f "$theDir/serial")       { $serial    = read_file("$theDir/serial"); chomp $serial }
   if ($idProduct && $idVendor) {
      $idCode = "$idVendor:$idProduct"; # the classical usb vendor:product string
      $idProduct = undef;
      $idVendor = undef
   }
   my $textOut = $text;
   $textOut .= " [" . $originalString . "] [points to dir '$theDir']";
   if ($dev || $product || $idProduct || $idVendor) {
      $textOut .= "\n";
      $textOut .= $indent;
      my $sep = "";
      if ($dev)       { $textOut .= "${sep}dev='$dev'"; $sep = ", " }
      if ($product)   { $textOut .= "${sep}product='$product'"; $sep = ", " }
      if ($idProduct) { $textOut .= "${sep}idProduct='$idProduct'"; $sep = ", " }
      if ($idVendor)  { $textOut .= "${sep}idVendor='$idVendor'"; $sep = ", " }
      if ($idCode)    { $textOut .= "${sep}id='$idCode'"; $sep = ", " }
      if ($version)   { $textOut .= "${sep}version='$version'"; $sep = ", " }
      if ($manuf)     { $textOut .= "${sep}manufacturer='$manuf'"; $sep = ", " }
      if ($serial)    { $textOut .= "${sep}serial='$serial'"; $sep = ", " }
   }
   if ($blockDev) {
      $textOut .= "\n";
      $textOut .= $indent;
      $textOut .= "The block device '$blockDev' with device path '$blockDevDir' matches this USB device path"
   } 
   return $textOut
}
 
# ===
# This is just for checking that the parsed entry is actually what was there in the first place
# ===

sub recomposeAndVerify {
   my ($curEntry,$bus,$portPath,$config,$interface) = @_;
   my $recomposed = "${bus}-";
   $recomposed .= join('.',@$portPath);
   if (defined($config)) {
      $recomposed .= ":${config}.${interface}"
   }
   if ($recomposed ne $curEntry) {
      print STDERR "Original entry '$curEntry' and recomposed entry '$recomposed' differ -- check your code!\n";
   }
}


# ===
# Traverse USB device tree and assign block device to "best match"
# ===

sub assignBlockDevicesToUsbTreeEntries {
   my ($curHash,$blockDevHash) = @_;
   #
   # Do all recursive calls FIRST in order to get best match
   #
   for my $curKey (sort keys %$curHash) {
      if ($curKey ne "") {
         assignBlockDevicesToUsbTreeEntries($$curHash{$curKey},$blockDevHash)
      }
   }
   #
   # Now check whether anything can be assigned (assigned elements have already been removed from "blockDevHash")
   #
   if (exists $$curHash{""}) {
      my $textHash = $$curHash{""};
      if (exists $$textHash{$DEVICE_DIR}) {
         my $devDir = $$textHash{$DEVICE_DIR};
         my $matched = 0;
         for my $blockDevDir (keys %$blockDevHash) {
            if ($blockDevDir =~ /^$devDir.*$/) {
               if ($matched) {
                  print STDERR "Duplicate match for '$devDir': matches '$blockDevDir' and $$textHash{$SD_DEVICE_DIR} -- exiting!\n";
                  exit 1
               }
               $matched = 1;
               $$textHash{$SD_DEVICE}     = $$blockDevHash{$blockDevDir};
               $$textHash{$SD_DEVICE_DIR} = $blockDevDir;
               delete $$blockDevHash{$blockDevDir} 
            }
         }
      }
   }
}


