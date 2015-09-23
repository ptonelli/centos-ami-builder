Description
===========

Script to create centos 6 ec2 ami, mostly copied from here_:

.. _here: http://guestslinuxstuff.blogspot.fr/2014/08/creating-amazon-centos-hvm-ami-with.html

First create a centos 6 HVM machine on amazon, connect to it and upgrade the
machine to have the latest packages (yum update -yes).

Create a 2Gb volume and attach it as /dev/sdb .

Copy the script to the machine and run it as root:

> sh builder.sh

After running the script, detach the volume, take a snapshot, register it as an
image using the amazon web interface.

Todo
====

- automatically install aws cli and use it to create volume, snapshot it and
  register the image automatically
- add options for centos 7 and root/non-root login.
