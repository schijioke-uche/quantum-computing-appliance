
#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description: SDLC automation script for IBM Bob operations
#===============================================================================

git pull origin main

chmod +x *.sh
chmod +x bqca/*.sh

git add -A 

git commit -m "Updated quantum appliance"

git push origin main