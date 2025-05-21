{
  nixpkgs,
  root,
  inputs,
}: config: let
  l = nixpkgs.lib // builtins;
  
  # Get system-specific packages
  pkgs = nixpkgs.legacyPackages.${config.system};
  
  # Import transformers library
  transformers = import ../../lib/transformers.nix { lib = l; pkgs = pkgs; };
  
  # Extract profile definition with defaults
  profile = transformers.withDefaults config {
    cpu = { cores = 1; "min-clock" = 0; architecture = "x86_64"; };
    memory = { "min-ram" = 1; "recommended-ram" = 2; };
    gpu = null;
    storage = { "min-disk" = 1; "temp-space" = 0; };
    network = { bandwidth = 0; ports = []; };
  };
  
  # Generate JSON profile file
  profileJson = pkgs.writeTextFile {
    name = "${profile.name}-profile.json";
    text = transformers.toJSON {
      name = profile.name;
      description = profile.description;
      cpu = profile.cpu;
      memory = profile.memory;
      gpu = profile.gpu;
      storage = profile.storage;
      network = profile.network;
    };
  };
  
  # Generate documentation using the transformers library
  profileDocs = transformers.generateDocs {
    name = "Resource Profile: ${profile.name}";
    description = profile.description;
    usage = ''
      ```bash
      # Check if your system meets the requirements
      check-profile-${profile.name}
      ```
    '';
    examples = ''
      ```bash
      # Check system compatibility
      check-profile-${profile.name}
      ```
    '';
    params = {
      cpu = {
        description = "CPU requirements";
        type = "attrset";
        value = profile.cpu;
      };
      memory = {
        description = "Memory requirements";
        type = "attrset";
        value = profile.memory;
      };
      gpu = {
        description = "GPU requirements (null if not required)";
        type = "attrset or null";
        value = profile.gpu;
      };
      storage = {
        description = "Storage requirements";
        type = "attrset";
        value = profile.storage;
      };
      network = {
        description = "Network requirements";
        type = "attrset";
        value = profile.network;
      };
    };
  };
  
  # Create a command to check if the current system meets the profile requirements
  checkScript = transformers.withArgs {
    name = "check-profile-${profile.name}";
    description = "Check if the current system meets the requirements of the ${profile.name} resource profile";
  } ''
    echo "Checking system against resource profile: ${profile.name}"
    echo ""
    
    # Check CPU
    echo "CPU Requirements:"
    CPU_CORES=$(nproc)
    echo "- Required cores: ${toString (profile.cpu.cores)}, Available: $CPU_CORES"
    if [ $CPU_CORES -lt ${toString (profile.cpu.cores)} ]; then
      echo "  ❌ Insufficient CPU cores"
    else
      echo "  ✅ Sufficient CPU cores"
    fi
    
    # Check Memory
    echo ""
    echo "Memory Requirements:"
    MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEM_TOTAL_GB=$((MEM_TOTAL_KB / 1024 / 1024))
    echo "- Required RAM: ${toString (profile.memory.min-ram)} GB, Available: $MEM_TOTAL_GB GB"
    if [ $MEM_TOTAL_GB -lt ${toString (profile.memory.min-ram)} ]; then
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
    echo "- Required disk: ${toString (profile.storage.min-disk)} GB, Available: $DISK_SPACE_GB GB"
    if [ $DISK_SPACE_GB -lt ${toString (profile.storage.min-disk)} ]; then
      echo "  ❌ Insufficient disk space"
    else
      echo "  ✅ Sufficient disk space"
    fi
  '';
  
  # Create derivations using the transformers library
  checkDrv = transformers.mkScript {
    name = "check-profile-${profile.name}";
    description = "Check if the current system meets the requirements of the ${profile.name} resource profile";
    script = checkScript;
  };
  
  docsDrv = transformers.mkDocs {
    name = "${profile.name}-profile";
    content = profileDocs;
  };
  
in {
  # Original profile configuration
  inherit (profile) name description;
  inherit (profile) cpu memory gpu storage network;
  
  # Derivations
  json = profileJson;
  documentation = docsDrv;
  check = checkDrv;
  
  # Add metadata
  metadata = profile.metadata or {};
}
