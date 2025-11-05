# Copyright (c) 2024 Akshay Srinivasan <akssri@vakra.xyz>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

{
  pkgs ? import (builtins.fetchGit { url = "https://github.com/akssri/nix-ros-overlay"; ref = "local"; }) {},
  rosDistro ? "jazzy",
}:
with pkgs;
with rosPackages.${rosDistro};

pkgs.mkShell {
  LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
  nativeBuildInputs = [
    (buildEnv {
      paths = [
        ros-core
        ros-environment
        std-msgs
        rosdep
        rosbag2
        colcon
        rclpy
        rclcpp
      ];
    })
  ];
  shellHook = ''
    export PATH=$PATH:${popf}/lib/popf

    # Setup ROS 2 shell completion. Doing it in direnv is useless.
    if [[ ! $DIRENV_IN_ENVRC ]]; then
        eval "$(${pkgs.python3Packages.argcomplete}/bin/register-python-argcomplete ros2)"
        eval "$(${pkgs.python3Packages.argcomplete}/bin/register-python-argcomplete colcon)"
    fi
  '';
}
