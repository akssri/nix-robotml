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

let
  system = builtins.currentSystem;
in
{
  pkgs ? import <nixpkgs> { inherit system; },
  rosDistro ? "jazzy",
}:
pkgs.mkShell {
  LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
  buildInputs = with pkgs; [
    (python3.withPackages (ps:
      with ps; [
        ipython
        pip
        numpy
        matplotlib
        jax
        jaxlib
      ]))
  ];
  # shellHook = ''
  #   export CUDA_HOME=${pkgs.cudaPackages.cudatoolkit}
  #   export CUDNN_HOME=${pkgs.cudaPackages.cudnn}
  #   export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
  #     pkgs.cudaPackages.cudatoolkit
  #     pkgs.cudaPackages.cudnn
  #     pkgs.linuxPackages.nvidia_x11
  #     pkgs.xorg.libX11
  #     pkgs.zlib
  #     pkgs.geos
  #     pkgs.glfw3
  #     pkgs.stdenv.cc.cc
  #   ]}
  #   export XLA_FLAGS="--xla_gpu_cuda_data_dir=${pkgs.cudaPackages.cudatoolkit}/nvvm/libdevice/"
  # '';
  shellHook = ''
    export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
      pkgs.geos
      pkgs.stdenv.cc.cc
      pkgs.glib
      pkgs.xorg.libX11
      pkgs.libGL
    ]}:$LD_LIBRARY_PATH
  '';
}
