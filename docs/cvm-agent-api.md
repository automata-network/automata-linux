# CVM Agent API

The server will broadcast on 2 ports:
- HTTPS: 0.0.0.0:8000 (for queries from outside of the TEE environment) 
- HTTP: 127.0.0.1:7999 (for internal workload use).

## API Reference

### Platform Information
- `/platform` [GET]
    - Port Availability: 7999
    - Returns information about the platform's TEE and cloud type
    - Response:
    ```json
    {
        "tee_type": <uint8>,
        "tee_name": <string>,
        "cloud_type": <uint8>,
        "cloud_name": <string>
    }
    ```

### Attestation APIs
- `/attestation` [POST]
    - Port Availability: 7999
    - Handles on-chain attestation requests with support for ZK proofs
    - Request Body:
    ```json
    {
        "extra_data": <32 bytes hex string>,
        "report_type": <integer>,
        "zk_config": {
            // Optional ZK proof configuration
        }
    }
    ```
    - Response:
    ```json
    {
        "report": <base64 encoded bytes>,
        "ak_pub": <base64 encoded bytes>,
        "zk_output": {
            // Optional ZK proof output
        },
        "vek_certs": [<base64 encoded bytes>],
        "tpm_quote": <base64 encoded bytes>,
        "tpm_signature": <base64 encoded bytes>,
        "tpm_pcrs": [
            {
                // PCR measurements
            }
        ],
        "tpm_certs": [<base64 encoded bytes>],
        "report_id": <base64 encoded bytes>,
        "golden_measurement": {
            // Golden measurement data
        }
    }
    ```

### Verification APIs
- `/offchain-verify` [POST]
    - Port Availability: 7999
    - Verifies CVM collaterals against golden measurements
    - Request Body:
    ```json
    {
        "collaterals_path": <string>,
        "golden_measurement_path": <string>,
        // Or provide the data directly:
        "collaterals": <string>,
        "golden_measurement": <string>
    }
    ```
    - Response:
    ```json
    {
        "success": <boolean>,
        "error": <string, optional>
    }
    ```

### Collaterals APIs
- `/collaterals/{nonce}`: [GET]
    - Port Availability: 7999, 8000
    - The nonce is used as it is for the TPM quote.
    - report_data field in the attestation report should contain the following:
      - On GCP/AWS: 0 * 32 || sha256sum(magic || nonce)
      - On Azure: sha256sum(HclVarData) || 0*32
    - extra_data field in the TPM Quote should contain the following:
      - On GCP/AWS: nonce
      - On Azure: magic || nonce 
    - magic = "External/collaterals" or "Internal/collaterals"
    - Returns a JSON structure containing the following:
    ```json
    {
        // Only sev_snp or tdx will be returned, not both at the same time.
        "sev_snp":
        {
            "attestation_report": <base64 encoded bytes>,
            "vek_cert": <base64 encoded bytes of X509 DER-encoded cert>
        },
        // Only sev_snp or tdx will be returned, not both at the same time.
        "tdx":
        {
            "attestation_report": <base64 encoded bytes>
        },
        "tpm":
        {
            "quote": <base64 encoded bytes>,
            "raw_sig": <base64 encoded bytes>,
            "pcrs":
            {
                "hash": <int, hash algorithm used for the values in the PCR>,
                // PCR number -> base64 encoded value of the value in the PCR
                "pcrs": <map<uint32><base64 encoded bytes>>
            },
            // Only used when ak_cert exists
            "ak_cert": <base64 encoded bytes of X509 DER-encoded cert>,
            // Only used if ak_pub is needed
            "ak_pub": <base64 encoded bytes of X509 DER-encoded SubjectPublicKeyInfo>,
            // Only used in Azure
            "var_data": <base64 encoded bytes>
        },
        "magic": <base64 encoded bytes>,
        "nonce": <base64 encoded bytes>,
        // 16-byte UUID, only used in GCP TDX.
        "uuid": <base64 encoded bytes>,
        "boot_log_tpm": <base64 encoded bytes>,
        // Only used in GCP TDX.
        "boot_log_ccel": <base64 encoded bytes>
    }
    ```

### Management APIs
- `/api-token`: [GET]
  - Port Availability: 8000
  - Retrieve the API token that can be used for `/update-workload` API. **This token can only be retrieved once**.
  - Returns a string of length 32.

- `/update-workload`: [POST]
    - Port Availability: 8000
    - Used to update the current workload on the server by uploading a .zip file containing a `workload/` folder.
    - It requires the following folder structure:
      ```
      workload/
          config/
              - all config files go here
          secrets/
              - all secrets go here
          docker-compose.yml
      ```
    - It requires authentication via a Bearer token.
    - Headers: `Authorization: Bearer <token>` (Required. Used for authenticating the request.)
    - Content-Type: multipart/form-data
    - Body: file (required): A .zip file uploaded via form-data.
    - Example: `curl -X POST -F "file=@output.zip" -H "Authorization: Bearer abcde12345" -k "https://<ip>:8000/update-workload"`
    - Returns a successful response after the new workload is successfully measured and running.

- `/golden-measurement` [GET]
    - Port Availability: 8000
    - Generates golden measurements for the current CVM
    - **Important Note**: Generated golden measurements are specific to:
        - The CVM type (SEV-SNP, TDX)
        - The cloud provider (Azure, GCP, AWS)
        - The VM size/configuration
    - Image creators must generate separate golden measurements for each unique combination of VM type, size, and cloud provider
    - Response:
    ```json
    {
        "golden_measurement": <json object>,
        "error": <string, optional>
    }
    ```
- `/maintenance-mode` [POST]Add commentMore actions
    - Port Availability: 8000
    - Purpose: Toggle the CVM into or out of maintenance mode by enabling / disabling SSH access to the operator container.
    - Authentication: same as `/update-workload` endpoint
    - Example Requests:
    ```bash
        # Immediately disable SSH
        curl -X POST http://<ip>:8000/maintenance-mode \
            -H "Content-Type: application/json" \
            -d '{"action":"disable"}'

        # Disable SSH after 30s
        curl -X POST http://<ip>:8000/maintenance-mode \
            -H "Content-Type: application/json" \
            -d '{"action":"disable", ,"delay_seconds":30}'

        # Immediately disable SSH
        curl -X POST http://<ip>:8000/maintenance-mode \
            -H "Content-Type: application/json" \
            -d '{"action":"enable"}'

        # Enable SSH again after 30 s
        curl -X POST http://<ip>:8000/maintenance-mode \
            -H "Content-Type: application/json" \
            -d '{"action":"enable","delay_seconds":30}'
    ```
    - Success Response
    ```json
    {
        "status": "maintenance mode triggered",      
        "maintenance_action": "enable",
        "port": "2222",
        "delay_seconds": 0,
        "results": {
            "operator": "operator\n"
        },
        "timestamp": "2025-07-01T01:34:32Z"
    }
    ```
