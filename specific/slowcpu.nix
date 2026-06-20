{ config, pkgs, ... }:

{
  # build settings for low-spec machines
  nix.settings = {
	  max-jobs = 1;
	  cores = 2;
  };
}