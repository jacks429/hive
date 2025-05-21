{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Extract profile definition
  profile = {
    inherit (config) name description;
    cpu = config.cpu or {};
    memory = config.memory or {};
    gpu = config.gpu or null;
    storage = config.storage or {};
    network = config.network or {};
  };
  
  # Generate JSON profile file
  profileJson = pkgs.writeTextFile {
    name = "${profile.name}-profile.json";
    text = builtins.toJSON {
      name = profile.name;
      description = profile.description;
      cpu = profile.cpu;
      memory = profile.memory;
      gpu = profile.gpu;
      storage = profile.storage;
      network = profile.network;
    };
  };
  
  # Generate markdown documentation
  profileMd = pkgs.writeTextFile {
    name = "${profile.name}-profile.md";
    text = ''
      # Resource Profile: ${profile.name}
      
      ${profile.description}
      
      ## CPU Requirements
      
      - **Cores**: ${toString (profile.cpu.cores or 1)}
      - **Min Clock**: ${toString (profile.cpu.min-clock or 0)} MHz
      - **Architecture**: ${profile.cpu.architecture or "x86_64"}
      
      ## Memory Requirements
      
      - **Min RAM**: ${toString (profile.memory.min-ram or 1)} GB
      - **Recommended RAM**: ${toString (profile.memory.recommended-ram or 2)} GB
      
      ${if profile.gpu != null then ''
      ## GPU Requirements
      
      - **Required**: ${if profile.gpu.required or false then "Yes" else "No"}
      - **Memory**: ${toString (profile.gpu.memory or 0)} GB
      - **CUDA Version**: ${profile.gpu.cuda-version or "N/A"}
      - **Vendor**: ${profile.gpu.vendor or "Any"}
      '' else "## GPU Requirements\n\nNo GPU required for this profile.\n"}
      
      ## Storage Requirements
      
      - **Min Disk**: ${toString (profile.storage.min-disk or 1)} GB
      - **Temp Space**: ${toString (profile.storage.temp-space or 0)} GB
      
      ## Network Requirements
      
      - **Bandwidth**: ${toString (profile.network.bandwidth or 0)} Mbps
      - **Ports**: ${l.concatStringsSep ", " (map toString (profile.network.ports or []))}
    '';
  };
  
  # Create a command to check if the current system meets the profile requirements
  checkScript = pkgs.writeShellScriptBin "check-profile-${profile.name}" ''
    #!/usr/bin/env bash
    
    echo "Checking system against resource profile: ${profile.name}"
    echo ""
    
    # Check CPU
    echo "CPU Requirements:"
    CPU_CORES=$(nproc)
    echo "- Required cores: ${toString (profile.cpu.cores or 1)}, Available: $CPU_CORES"
    if [ $CPU_CORES -lt ${toString (profile.cpu.cores or 1)} ]; then
      echo "  ❌ Insufficient CPU cores"
    else
      echo "  ✅ Sufficient CPU cores"
    fi
    
    # Check Memory
    echo ""
    echo "Memory Requirements:"
    MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEM_TOTAL_GB=$((MEM_TOTAL_KB / 1024 / 1024))
    echo "- Required RAM: ${toString (profile.memory.min-ram or 1)} GB, Available: $MEM_TOTAL_GB GB"
    if [ $MEM_TOTAL_GB -lt ${toString (profile.memory.min-ram or 1)} ]; then
      echo "  ❌ Insufficient RAM"
    else
      echo "  ✅ Sufficient RAM"
    fi
    
    ${if profile.gpu != null && (profile.gpu.required or false) then ''
    # Check GPU
    echo ""
    echo "GPU Requirements:"
    if command -v nvidia-smi &> /dev/null; then
      GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader)
      echo "- GPU detected: $GPU_INFO"
      echo "  ✅ GPU available"
    else
      echo "- No NVIDIA GPU detected"
      echo "  ❌ Required GPU not found"
    fi
    '' else ""}
    
    # Check Disk
    echo ""
    echo "Storage Requirements:"
    DISK_SPACE_KB=$(df -k . | tail -1 | awk '{print $4}')
    DISK_SPACE_GB=$((DISK_SPACE_KB / 1024 / 1024))
    echo "- Required disk: ${toString (profile.storage.min-disk or 1)} GB, Available: $DISK_SPACE_GB GB"
    if [ $DISK_SPACE_GB -lt ${toString (profile.storage.min-disk or 1)} ]; then
      echo "  ❌ Insufficient disk space"
    else
      echo "  ✅ Sufficient disk space"
    fi
  '';
  
in {
  # Original profile configuration
  inherit (profile) name description;
  inherit (profile) cpu memory gpu storage network;
  
  # Derivations
  json = profileJson;
  documentation = profileMd;
  check = checkScript;
  
  # Add metadata
  metadata = config.metadata or {};
}
