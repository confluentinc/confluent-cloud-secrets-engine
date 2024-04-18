# Documentation How-To

## Publishing new documentation

To publish new documentation, first ensure the latest version of the `confluent-cloud-secrets-engine` repo is present.

Then run the following command:

```bash
./publish-github-page-docs.sh
```

Make sure the file is executable, if not this can be done by running
```bash
chmod +x publish-github-page-docs.sh 
```

## Accessing documentation

To access the documentation navigate to [confluent-cloud-secrets-engine](https://github.com/confluentinc/confluent-cloud-secrets-engine)
or locally run the following command:

```bash
./preview-github-page-docs.sh
```

Make sure the file is executable, if not this can be done by running:
```bash
chmod +x preview-github-page-docs.sh
```

## Adding new documentation

When adding new documentation save the document as `new_document.md` in the `astrodocs/src/content/docs` directory.

Visit the [README](astrodocs/README.md) for more information.
