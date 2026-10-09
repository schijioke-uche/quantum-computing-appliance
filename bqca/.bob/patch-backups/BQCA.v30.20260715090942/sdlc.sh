#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description: SDLC automation script for IBM Bob Quantum Computing Agent Appliance
#===============================================================================

git pull origin main

chmod +x *.sh
chmod +x ~/*/quantum-computing-agent/*.sh


git add -A 

git commit -m "Updated IBM Bob Quantum Computing Agent Appliance"

git push origin main


