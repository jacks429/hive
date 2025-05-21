#!/usr/bin/env python

import json
import os
import sys
import argparse
import great_expectations as ge
from great_expectations.core.batch import RuntimeBatchRequest
from great_expectations.data_context import BaseDataContext
from great_expectations.data_context.types.base import DataContextConfig

def main():
    # Parse arguments
    parser = argparse.ArgumentParser(description='Great Expectations data validator')
    parser.add_argument('--data-path', required=True, help='Path to dataset')
    parser.add_argument('--output-path', required=True, help='Path to save validation results')
    parser.add_argument('--config', required=True, help='Path to validation config')
    args = parser.parse_args()
    
    # Load config
    with open(args.config, 'r') as f:
        config = json.load(f)
    
    # Create Great Expectations context
    context_config = DataContextConfig(
        store_backend_defaults={"class_name": "InMemoryStoreBackend"},
        expectations_store_name="expectations_store",
        validations_store_name="validations_store",
        evaluation_parameter_store_name="evaluation_parameter_store",
    )
    context = BaseDataContext(project_config=context_config)
    
    # Load data
    if args.data_path.endswith('.csv'):
        import pandas as pd
        df = pd.read_csv(args.data_path)
        datasource = context.add_datasource(
            "my_datasource",
            class_name="Datasource",
            execution_engine={"class_name": "PandasExecutionEngine"},
            data_connectors={
                "default_runtime_data_connector": {
                    "class_name": "RuntimeDataConnector",
                    "batch_identifiers": ["batch_id"],
                }
            },
        )
        
        # Create batch request
        batch_request = RuntimeBatchRequest(
            datasource_name="my_datasource",
            data_connector_name="default_runtime_data_connector",
            data_asset_name="my_data_asset",
            batch_identifiers={"batch_id": "default_identifier"},
            runtime_parameters={"batch_data": df},
        )
    else:
        raise ValueError(f"Unsupported file format: {args.data_path}")
    
    # Create expectation suite
    expectation_suite_name = config["name"]
    context.create_expectation_suite(expectation_suite_name, overwrite_existing=True)
    
    # Create validator
    validator = context.get_validator(
        batch_request=batch_request,
        expectation_suite_name=expectation_suite_name,
    )
    
    # Add expectations
    for expectation in config["expectations"]:
        # Get expectation type and parameters
        expectation_type = expectation["type"]
        expectation_params = {k: v for k, v in expectation.items() if k != "type"}
        
        # Call the appropriate expectation method
        getattr(validator, expectation_type)(**expectation_params)
    
    # Save expectation suite
    validator.save_expectation_suite(discard_failed_expectations=False)
    
    # Validate data
    results = validator.validate()
    
    # Create output directory
    os.makedirs(args.output_path, exist_ok=True)
    
    # Save validation results
    with open(f"{args.output_path}/validation_result.json", 'w') as f:
        json.dump({
            "passed": results.success,
            "results": results.to_json_dict(),
            "statistics": {
                "evaluated_expectations": results.statistics["evaluated_expectations"],
                "successful_expectations": results.statistics["successful_expectations"],
                "unsuccessful_expectations": results.statistics["unsuccessful_expectations"],
                "success_percent": results.statistics["success_percent"],
            }
        }, f, indent=2)
    
    # Return success or failure
    return 0 if results.success else 1

if __name__ == "__main__":
    sys.exit(main())