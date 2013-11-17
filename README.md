list_sd_devices_on_usb_bus
==========================

What
----

A simple script to find the USB-attached SCSI disk device (and list the USB device tree, too) on Linux.

Why
---

This is an exercise in understanding how the Linux `/sys` tree and the USB device tree look like. I also
wanted to just check whether any of the `/dev/sd*` devices where actually on the USB bus. 

Hence this script. 

See also
--------

See also these utilities which should come with your distribution:

  * `lsusb`
  * `usbview`

As well as:

  * http://www.linux-usb.org/FAQ.html
  * https://www.kernel.org/doc/htmldocs/usb/API-struct-usb-device.html
  
Example output
--------------

In this example, the system has a harddisk with brand "Intenso" hanging off a USB bus. It has vendor:product id "152d:0539".

`lsusb -t`then yields the following:

    $ lsusb -t
    /:  Bus 04.Port 1: Dev 1, Class=root_hub, Driver=ohci_hcd/5p, 12M
        |__ Port 1: Dev 2, If 0, Class=HID, Driver=usbhid, 1.5M
        |__ Port 2: Dev 3, If 0, Class=HID, Driver=usbhid, 12M
        |__ Port 2: Dev 3, If 1, Class=HID, Driver=usbhid, 12M
    /:  Bus 03.Port 1: Dev 1, Class=root_hub, Driver=ohci_hcd/5p, 12M
        |__ Port 2: Dev 2, If 0, Class=hub, Driver=hub/4p, 12M
            |__ Port 1: Dev 3, If 0, Class=HID, Driver=usbhid, 1.5M
            |__ Port 1: Dev 3, If 1, Class=HID, Driver=usbhid, 1.5M
            |__ Port 4: Dev 4, If 0, Class=HID, Driver=usbhid, 12M
    /:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=ehci-pci/5p, 480M
    /:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=ehci-pci/5p, 480M
        |__ Port 1: Dev 5, If 0, Class=stor., Driver=usb-storage, 480M

or simply using `lsusb`:

    Bus 001 Device 005: ID 152d:0539 JMicron Technology Corp. / JMicron USA Technology Corp. 
    Bus 003 Device 002: ID 046d:c223 Logitech, Inc. G11/G15 Keyboard / USB Hub
    Bus 004 Device 002: ID 1050:0010 Yubico.com Yubikey
    Bus 004 Device 003: ID 046d:c52e Logitech, Inc. 
    Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
    Bus 002 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
    Bus 003 Device 001: ID 1d6b:0001 Linux Foundation 1.1 root hub
    Bus 004 Device 001: ID 1d6b:0001 Linux Foundation 1.1 root hub
    Bus 003 Device 003: ID 046d:c221 Logitech, Inc. G11/G15 Keyboard / Keyboard
    Bus 003 Device 004: ID 046d:c225 Logitech, Inc. G11/G15 Keyboard / G keys

Running this script yields something both harder to read and more informative. Note that I have no idea from where lsusb 
gets its "device 5 on bus 1". The output shows that USB device "1-1:1.0" (bus 1, port 1, config 1, interface 0) is the
device providing for `/dev/sdd`:

    bus 1 -> port 0 -> config 1 -> interface 0 [1-0:1.0] [points to dir '/sys/devices/pci0000:00/0000:00:02.1/usb1/1-0:1.0']
    bus 1 -> port 1 [1-1] [points to dir '/sys/devices/pci0000:00/0000:00:02.1/usb1/1-1']
         dev='189:4', product='External USB 3.0', id='152d:0539', version=' 2.10', manufacturer='Intenso', serial='201212010088'
    bus 1 -> port 1 -> config 1 -> interface 0 [1-1:1.0] [points to dir '/sys/devices/pci0000:00/0000:00:02.1/usb1/1-1/1-1:1.0']
         The block device 'sdd' with device path '/sys/devices/pci0000:00/0000:00:02.1/usb1/1-1/1-1:1.0/host8/target8:0:0/8:0:0:0/block/sdd' matches this USB device path
    bus 2 -> port 0 -> config 1 -> interface 0 [2-0:1.0] [points to dir '/sys/devices/pci0000:00/0000:00:04.1/usb2/2-0:1.0']
    bus 3 -> port 0 -> config 1 -> interface 0 [3-0:1.0] [points to dir '/sys/devices/pci0000:00/0000:00:02.0/usb3/3-0:1.0']
    bus 3 -> port 2 [3-2] [points to dir '/sys/devices/pci0000:00/0000:00:02.0/usb3/3-2']
         dev='189:257', product='G11 Keyboard', id='046d:c223', version=' 1.10'
    bus 3 -> port 2 -> config 1 -> interface 0 [3-2:1.0] [points to dir '/sys/devices/pci0000:00/0000:00:02.0/usb3/3-2/3-2:1.0']
    bus 3 -> port 2 -> port 1 [3-2.1] [points to dir '/sys/devices/pci0000:00/0000:00:02.0/usb3/3-2/3-2.1']
        dev='189:258', product='Gaming Keyboard', id='046d:c221', version=' 2.00'
    bus 3 -> port 2 -> port 1 -> config 1 -> interface 0 [3-2.1:1.0] [points to dir '/sys/devices/pci0000:00/0000:00:02.0/usb3/3-2/3-2.1/3-2.1:1.0']
    bus 3 -> port 2 -> port 1 -> config 1 -> interface 1 [3-2.1:1.1] [points to dir '/sys/devices/pci0000:00/0000:00:02.0/usb3/3-2/3-2.1/3-2.1:1.1']
    bus 3 -> port 2 -> port 4 [3-2.4] [points to dir '/sys/devices/pci0000:00/0000:00:02.0/usb3/3-2/3-2.4']
         dev='189:259', product='G11 Keyboard', id='046d:c225', version=' 2.00'
    bus 3 -> port 2 -> port 4 -> config 1 -> interface 0 [3-2.4:1.0] [points to dir '/sys/devices/pci0000:00/0000:00:02.0/usb3/3-2/3-2.4/3-2.4:1.0']
    bus 4 -> port 0 -> config 1 -> interface 0 [4-0:1.0] [points to dir '/sys/devices/pci0000:00/0000:00:04.0/usb4/4-0:1.0']
    bus 4 -> port 1 [4-1] [points to dir '/sys/devices/pci0000:00/0000:00:04.0/usb4/4-1']
        dev='189:385', product='Yubico Yubikey II', id='1050:0010', version=' 2.00', manufacturer='Yubico'
    bus 4 -> port 1 -> config 1 -> interface 0 [4-1:1.0] [points to dir '/sys/devices/pci0000:00/0000:00:04.0/usb4/4-1/4-1:1.0']
    bus 4 -> port 2 [4-2] [points to dir '/sys/devices/pci0000:00/0000:00:04.0/usb4/4-2']
         dev='189:386', product='USB Receiver', id='046d:c52e', version=' 2.00', manufacturer='Logitech'
    bus 4 -> port 2 -> config 1 -> interface 0 [4-2:1.0] [points to dir '/sys/devices/pci0000:00/0000:00:04.0/usb4/4-2/4-2:1.0']
    bus 4 -> port 2 -> config 1 -> interface 1 [4-2:1.1] [points to dir '/sys/devices/pci0000:00/0000:00:04.0/usb4/4-2/4-2:1.1']


License
-------

Distributed under the MIT License, see http://opensource.org/licenses/MIT

Copyright (c) 2013<br>
David Tonhofer<br>
14, rue Aldringen<br>
L-1118 Luxembourg<br>
 
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
