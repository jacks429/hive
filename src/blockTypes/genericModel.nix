# Generic model block type definition
{ inputs, cell, kind, cliPrefix ? "run" }: config: {
  # Standard model interface
  modelUri = config.modelUri or null;
  framework = config.framework or "huggingface";
  params = config.params or {};
  
  # Metadata
  meta = {
    name = config.name or "${cell.__cell}/${cell.__target}";
    description = config.description or "";
    kind = kind;
    tags = config.tags or [];
    license = config.license or "unknown";
    metrics = config.metrics or {};
  } // (config.meta or {});
  
  # Service configuration (optional)
  service = config.service or {
    enable = false;
    host = "0.0.0.0";
    port = 8000;
  };
  
  # System information
  system = config.system or "x86_64-linux";
}