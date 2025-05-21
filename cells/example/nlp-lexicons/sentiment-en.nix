{
  inputs,
  cell,
}: {
  name = "sentiment-en";
  description = "English sentiment lexicon with positive and negative scores";
  
  # Lexicon type
  type = "sentiment";
  
  # Source configuration - tab-separated values with word and sentiment score
  source = ''
    good	1.0
    great	1.5
    excellent	2.0
    amazing	2.0
    wonderful	1.8
    fantastic	1.9
    terrific	1.7
    outstanding	1.8
    superb	1.9
    brilliant	1.8
    bad	-1.0
    terrible	-2.0
    awful	-1.8
    horrible	-1.9
    poor	-1.0
    disappointing	-1.2
    miserable	-1.5
    dreadful	-1.7
    abysmal	-1.9
    appalling	-1.8
    like	0.8
    love	1.5
    hate	-1.5
    dislike	-0.8
    enjoy	1.0
    happy	1.2
    sad	-1.2
    angry	-1.3
    pleased	1.1
    disappointed	-1.1
    satisfied	1.0
    unsatisfied	-1.0
    content	0.9
    discontent	-0.9
    delighted	1.4
    upset	-1.1
    glad	1.0
    sorry	-0.7
    fortunate	1.0
    unfortunate	-1.0
    positive	1.0
    negative	-1.0
    success	1.2
    failure	-1.2
    win	1.0
    lose	-1.0
    victory	1.3
    defeat	-1.3
  '';
  
  # Format configuration
  format = "tsv";
  outputFormat = "json";
  
  # Processing options
  caseSensitive = false;
  normalize = true;
  stemming = false;
  lemmatization = false;
  
  # Language information
  language = "en";
  
  # System information
  system = "x86_64-linux";
}