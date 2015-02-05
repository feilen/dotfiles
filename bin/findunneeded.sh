#!/bin/bash

# Find packages which are not a required dependency of any package.

yaourt -Qi|sed '/Name\|Required By/!d'|grep -B1 None|sed '/Name/!d;s/.*: //g'
