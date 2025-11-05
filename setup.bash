#!/usr/bin/env bash
DIRECTORY=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
pushd $PWD

# source nix env
cd $DIRECTORY
eval "$(nix print-dev-env $DIRECTORY)"

# source venv
if [ -f $DIRECTORY/venv/bin/activate ]; then
    source $DIRECTORY/venv/bin/activate
fi
# source ros2
if [ -d ${DIRECTORY}/ros_ws/install ]; then
    cd $DIRECTORY/ros_ws/install && source setup.bash
fi

# return to pwd
popd

export ROS_DOMAIN_ID=0

# export CUDA_VISIBLE_DEVICES=""
export XLA_PYTHON_CLIENT_PREALLOCATE="false"
export DISPLAY=:0

eval "$(register-python-argcomplete ros2)"
eval "$(register-python-argcomplete colcon)"
