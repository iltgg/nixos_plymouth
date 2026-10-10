#!/usr/bin/env bash

sudo plymouthd
sudo plymouth --show-splash
sleep 5
sudo plymouth ask-for-password --prompt "Please enter passphrase"
sudo plymouth quit
