#!/bin/bash

loadkeys us
setfont Lat2-Terminus
sed -i "s/^pl_/#pl_/" /etc/locale.gen
sed -i "s/^cs_/#cs_/" /etc/locale.gen
