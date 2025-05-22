{
  inputs,
  cell,
}: {
  name = "exploratory-analysis";
  description = "Jupyter notebook for exploratory data analysis";
  
  kernelName = "python3";
  
  dependencies = {
    python = [
      "numpy"
      "pandas"
      "matplotlib"
      "seaborn"
      "scikit-learn"
      "jupyter"
    ];
  };
  
  # Template notebook content (optional)
  template = {
    cells = [
      {
        cell_type = "markdown";
        source = "# Exploratory Data Analysis\n\nThis notebook provides a template for exploratory data analysis.";
      }
      {
        cell_type = "code";
        source = ''
          import numpy as np
          import pandas as pd
          import matplotlib.pyplot as plt
          import seaborn as sns
          
          # Set plot style
          plt.style.use('ggplot')
          sns.set(style="whitegrid")
          
          # Display settings
          pd.set_option('display.max_columns', None)
          pd.set_option('display.max_rows', 100)
        '';
        metadata = {};
        execution_count = null;
        outputs = [];
      }
      {
        cell_type = "markdown";
        source = "## Load Data";
      }
      {
        cell_type = "code";
        source = ''
          # Load your dataset
          # df = pd.read_csv('your_data.csv')
          
          # Display basic information
          # df.info()
          # df.describe()
        '';
        metadata = {};
        execution_count = null;
        outputs = [];
      }
      {
        cell_type = "markdown";
        source = "## Data Visualization";
      }
      {
        cell_type = "code";
        source = ''
          # Example visualizations
          # plt.figure(figsize=(12, 8))
          # sns.heatmap(df.corr(), annot=True, cmap='coolwarm')
          # plt.title('Correlation Matrix')
          # plt.show()
        '';
        metadata = {};
        execution_count = null;
        outputs = [];
      }
    ];
    metadata = {
      kernelspec = {
        display_name = "Python 3";
        language = "python";
        name = "python3";
      };
      language_info = {
        codemirror_mode = {
          name = "ipython";
          version = 3;
        };
        file_extension = ".py";
        mimetype = "text/x-python";
        name = "python";
        nbconvert_exporter = "python";
        pygments_lexer = "ipython3";
        version = "3.8.10";
      };
    };
    nbformat = 4;
    nbformat_minor = 5;
  };
  
  # System information
  system = "x86_64-linux";
}