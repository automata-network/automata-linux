# 🧩 Image Policy Fields

The image signature verification policy defines the rules that govern which container images are trusted and allowed to run. It follows the industry image signature verification standard defiend by [Containers](https://github.com/containers/image/blob/main/docs/containers-policy.json.5.md). The example policy is following:

```json
{
    "default": [{"type": "reject"}],
    "transports": {
        "docker": {
            "[REGISTRY_URL]": [
                {
                    "type": "sigstoreSigned",
                    "keyPath": "/data/workload/secret/cosign.pub",
                    "signedIdentity": { "type": "matchRepository" } 
                }
            ]
        }
    }
}
```

The two top-level fields are:

| Field        | Description |
|--------------|-------------|
| `default`    | Fallback rule applied when no transport-specific match is found. Typically set to `"reject"` to block all unsigned or unknown images. |
| `transports` | A mapping of image transports (e.g., `docker`) to per-registry trust policies. Overrides the default policy for explicitly listed registries. |

> [!Note]
> The detailed explaination of the policy and be found in the opensource project [Image](https://github.com/containers/image/blob/main/docs/containers-policy.json.5.md).
> Currently we only support `sigstoreSigned` and user must specify their signing key in the policy.

---

## Signature Rule (Sigstore)

A common rule for trusted registries involves requiring images to be signed using [Sigstore Cosign](https://github.com/sigstore/cosign)

| Field     | Description |
|-----------|-------------|
| `type`    | Specifies that the image must be signed using **Sigstore** (via Cosign). |
| `keyPath` | Path to the trusted public key used to verify the image signature. |

---

## Example: Trust Only Signed Images from a Specific Registry

```json
"docker": {
    "ghcr.io/automata": [
        {
            "type": "sigstoreSigned",
            "keyPath": "/data/workload/secret/cosign.pub"
        }
    ]
}
```

This rule ensures that:

- Only images pulled from `ghcr.io/automata` that are **signed using the specified Cosign key** stored in **/data/workload/secret/cosign.pub** are allowed.
- All other images are blocked due to the fallback `default: reject` rule.

---

## Security Best Practices

- **✅ Use `default: reject`** to block all images unless explicitly trusted.
- **🚫 Avoid wildcards** like `*` unless used carefully and scoped to trusted sources (e.g., `ghcr.io/automata/*`).


---

## How to sign a image using cosign:

User can use our cvm-cli tool to sign the image and push it to the remote repo. Note that 

```bash
./cvm-cli sign-image  <source-image-name> <target-image-name> <cosign-private-key> <cosign-public-key>
```
> [!Note]
> The image signature is stored with the image in the remote repo. The cvm-agent will pull the image signature at runtime automaticly
