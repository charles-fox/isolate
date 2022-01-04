# Isolate -- convert nasm to bootable ISO

This is the Linux branch.   For Windows, switch to the master branch!

## Installation

Install NASM.   On Debian based machines this can be done with

```console
sudo apt install nasm -y
```

Install and build isolate:
```console
git clone -b linux https://github.com/charles-fox/isolate.git
cd isolate; dotnet build; cd bin/Debug/net5.0/
```

Test by 'isolating' a demo program:
```console
/isolate hello16.asm hello16.iso
```

The ISO can be booted on a virtual machine as if it was a physical disc. We will use the Virtual Box virtual machine. To download and run Virtual Box,
```console
sudo apt install virtualbox;
virtualbox
```

Create a new virtual machine (‘New’ icon; use default settings). Start it upand ‘insert’ your bootable ISO disc when asked.


## Linux Workshop Files
https://docs.google.com/document/d/1lvtMqFPLnLseZ9mZF34hVPCHYj4bRMQC6VRW0F9qidc/edit

## ISO & bootloader docs links
https://krisj.dev/posts/iso9660/

https://krisj.dev/posts/x86_bootloaders/
