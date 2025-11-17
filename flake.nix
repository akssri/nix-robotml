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
  inputs = {
    nix-ros-overlay.url = github:akssri/nix-ros-overlay/local;
    nixpkgs.follows = "nix-ros-overlay/nixpkgs";  # IMPORTANT!!!
  };
  outputs = { self, nix-ros-overlay, nixpkgs }:
    nix-ros-overlay.inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        # config
        rosDistro = "jazzy";
        cudaSupport = false;

        pkgs-overlay = (final: prev: {
          opencv = (prev.opencv.override {
            enableGtk2 = true;
          });
          python3 = prev.python312.override {
            packageOverrides = pyfinal: pyprev: rec {
              jax = (pyprev.jax.override {
                cudaSupport = cudaSupport;
              });
              jaxlib-bin = (pyprev.jaxlib-bin.override {
                # cudaSupport = true;
              });
              jaxlib = pyfinal.jaxlib-bin;
              keras = pyprev.keras.overrideAttrs (oldAttrs: rec {
                version = "3.10.0";
                src = pkgs.fetchFromGitHub {
                  owner = "keras-team";
                  repo = "keras";
                  rev = "v${version}";
                  sha256 = "sha256-N0RlXnmSYJvD4/a47U4EjMczw1VIyereZoPicjgEkAI=";
                };
              });
              opencv4 = (pyprev.opencv4.override {
                enableGtk2 = true;
              });
              pybullet = pyprev.pybullet.overrideAttrs (oldAttrs: rec {
                NIX_CFLAGS_COMPILE = "-Wno-error=incompatible-pointer-types";
              });
              quaternion = pyprev.quaternion.overridePythonAttrs (oldAttrs: rec {
                version = "2024.0.8";
                src = pkgs.fetchFromGitHub {
                  owner = "moble";
                  repo = "quaternion";
                  tag = "v${version}";
                  hash = "sha256-Le9i7oFPcBuZw/oNwCxz3svzKg9zREk4peIJadTiJ/M=";
                };
                nativeBuildInputs = oldAttrs.nativeBuildInputs or [] ++ [
                  pyfinal.hatchling
                  pyfinal.setuptools
                  pyfinal.wheel
                ];
              });
              tensorflow-datasets = null;
              # tensorflow-probability = (pyfinal.callPackage (import ./tfp) {});
              tensorflow-probability = pyprev.tensorflow-probability.overridePythonAttrs (oldAttrs: rec {
                src = oldAttrs.src.overrideAttrs (oldBzlAttrs: rec {
                  nativeBuildInputs = builtins.filter (dep: dep != pyfinal.tensorflow) oldBzlAttrs.nativeBuildInputs;
                });
                dependencies = (builtins.filter (dep: dep != pyfinal.tensorflow && dep != pyfinal.keras) oldAttrs.dependencies)
                               ++ [pyfinal.jax];
              });
            };
          };
        });
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nix-ros-overlay.overlays.default pkgs-overlay ];
          config.allowUnfree = true;
          # config.cudaSupport = true;
        };
        mergeEnvs = envs: pkgs.mkShell (builtins.foldl' (a: v: {
          buildInputs = a.buildInputs ++ v.buildInputs;
          nativeBuildInputs = a.nativeBuildInputs ++ v.nativeBuildInputs;
          propagatedBuildInputs = a.propagatedBuildInputs ++ v.propagatedBuildInputs;
          propagatedNativeBuildInputs = a.propagatedNativeBuildInputs ++ v.propagatedNativeBuildInputs;
          shellHook = a.shellHook + "\n" + v.shellHook;
          LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
        }) (pkgs.mkShell {}) envs);
        # ros
        ros-env = import ./ros-shell.nix { inherit pkgs rosDistro; };
        # ml
        ml-env = import ./ml-shell.nix { inherit pkgs rosDistro; };
        # merge
        merge-env = mergeEnvs [ros-env ml-env];
        # docker fn
        docker_fn = (env : name : pkgs.dockerTools.buildLayeredImage {
          name = name;
          tag = "latest";
          maxLayers = 120;
          contents =
            env.buildInputs ++ env.nativeBuildInputs ++
            (with pkgs;
              [ coreutils
                bash gnugrep git
                # set up users and groups
                (writeTextDir "etc/shadow" ''
                  root:!x:::::::
                  dev:!x:::::::
                '')
                (writeTextDir "etc/passwd" ''
                  root:x:0:0::/root:${runtimeShell}
                  dev:x:1000:100::/home:${runtimeShell}
                '')
                (writeTextDir "etc/group" ''
                  root:x:0:
                  users:x:100:dev
                '')
                (writeTextDir "etc/gshadow" ''
                  root:x::
                  users:x::
                '')
              ]);
          extraCommands = ''
              mkdir -p tmp root home
              chmod a+r+w tmp
              chown -R 1000:100 home
          '';
          config = {
            Env = [ "LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/lib:/usr/lib64" ];
            Cmd = [ "/bin/bash" ];
          };
        });
      in rec {
        devShells.default = merge-env;
        devShells.ros = ros-env;
        devShells.ml = ml-env;
        devShells.ipython = mergeEnvs [ros-env ml-env (pkgs.mkShell {shellHook = "ipython";}) ];
        # nix build .#docker.x86_64-linux
        # podman load < result
        # podman run -it --rm --device nvidia.com/gpu=all localhost/nix-ros-ml bash
        docker-ml = docker_fn ml-env "nix-ml";
        docker-ros = docker_fn ros-env "nix-ros";
        docker = docker_fn merge-env "nix-ros-ml";
      });
  nixConfig = {
    extra-substituters = [ "https://d28aqux74a45x3.cloudfront.net/nix" "https://ros.cachix.org" "https://cuda-maintainers.cachix.org" ];
    extra-trusted-public-keys = [ "vakra:eOu11CBc9isYEg4IHAsfIHwdfWps/9Mf3MvncLBsGL8=" "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo=" "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=" ];
  };
}
