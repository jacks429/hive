{
  inputs,
  cell,
}: {
  name = "image-classifier";
  description = "A simple image classification model using ResNet50";
  
  framework = "pytorch";
  
  architecture = {
    type = "resnet50";
    pretrained = true;
    num_classes = 1000;
  };
  
  params = {
    dropout = 0.5;
    activation = "relu";
  };
  
  training = {
    batchSize = 64;
    epochs = 20;
    optimizer = "adam";
    learningRate = 0.001;
    weightDecay = 1e-5;
    scheduler = "cosine";
  };
  
  metrics = [
    "accuracy"
    "precision"
    "recall"
    "f1"
  ];
  
  # Optional service configuration
  service = {
    enable = true;
    host = "0.0.0.0";
    port = 8080;
    maxConcurrentRequests = 10;
  };
  
  # System information
  system = "x86_64-linux";
}
