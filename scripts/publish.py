#!/usr/bin/env python3
"""
Script for updating MCP Hive with custom payload and zip file.
Usage:
    python publish.py --api-key YOUR_KEY --hive-id HIVE_ID --zip-path path/to/zip --custom-payload path/to/payload.json
"""

import argparse
import json
import os
import sys
from typing import Dict, Any, Optional
import requests


class MCPHiveUpdater:
    def __init__(
        self, base_url: str = "https://mcp-hive.ti.trilogy.com", api_key: Optional[str] = None
    ):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key

    def get_headers(self) -> Dict[str, str]:
        """Get headers for API requests"""
        headers = {}
        if self.api_key:
            headers["x-api-key"] = f"{self.api_key}"
        return headers

    def update_hive_from_mcp_server(
        self, hive_id: str, zip_path: str, payload_path: str
    ) -> Dict[str, Any]:
        """Update an existing hive from MCP server"""
        url = f"{self.base_url}/api/hives/{hive_id}/from-mcp-server"

        # Read payload data
        with open(payload_path, "r") as f:
            data = json.load(f)

        # Prepare the multipart form data
        with open(zip_path, "rb") as zip_file:
            files = {
                "zipFile": (os.path.basename(zip_path), zip_file, "application/zip")
            }
            form_data = {"data": json.dumps(data)}

            response = requests.put(
                url, files=files, data=form_data, headers=self.get_headers()
            )

        return self._handle_response(response)

    def _handle_response(self, response: requests.Response) -> Dict[str, Any]:
        """Handle API response"""
        print(f"Status Code: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")

        try:
            result = response.json()
            print(f"Response Body: {json.dumps(result, indent=2)}")

            if response.status_code >= 400:
                print(f"❌ Error: {result.get('error', 'Unknown error')}")
                sys.exit(1)
            else:
                print("✅ Success!")
                return result

        except json.JSONDecodeError:
            print(f"❌ Invalid JSON response: {response.text}")
            sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Update MCP Hive with custom payload")
    parser.add_argument("--api-key", required=True, help="API key for authentication")
    parser.add_argument(
        "--hive-id", 
        required=True,
        help="Hive ID to update"
    )
    parser.add_argument(
        "--zip-path", 
        required=True,
        help="Path to the zip file"
    )
    parser.add_argument(
        "--custom-payload", 
        required=True,
        help="Path to custom JSON payload file"
    )
    parser.add_argument(
        "--base-url", 
        default="https://mcp-hive.ti.trilogy.com", 
        help="Base URL for the API"
    )

    args = parser.parse_args()

    # Verify files exist
    if not os.path.exists(args.zip_path):
        print(f"❌ Error: Zip file not found: {args.zip_path}")
        sys.exit(1)
    
    if not os.path.exists(args.custom_payload):
        print(f"❌ Error: Payload file not found: {args.custom_payload}")
        sys.exit(1)

    # Initialize updater
    updater = MCPHiveUpdater(base_url=args.base_url, api_key=args.api_key)

    # Read and display payload content
    with open(args.custom_payload, "r") as f:
        payload_data = json.load(f)
    
    print("🚀 Updating MCP Hive...")
    print(f"📁 Zip file: {args.zip_path}")
    print(f"📋 Payload file: {args.custom_payload}")
    print(f"🆔 Hive ID: {args.hive_id}")
    print(f"📋 Version: {payload_data.get('version', 'Unknown')}")
    print(f"📋 Payload content: {json.dumps(payload_data, indent=2)}")
    print("-" * 50)

    try:
        result = updater.update_hive_from_mcp_server(
            args.hive_id, args.zip_path, args.custom_payload
        )
        print("\n🎉 Hive updated successfully!")
        print(f"Hive ID: {result.get('hive', {}).get('id')}")
        print(f"Version: {result.get('hive', {}).get('version')}")

    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()