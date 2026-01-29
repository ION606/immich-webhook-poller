# Immich Monitor

A simple bash program to poll your immich install and send any new file IDs/types to predefined webhooks

## Configuration

You need "two" files to run this program (one if you directly inject the envars into the env). The first file should be `.env` and be structured like:

```env
IMMICH_BASE_URL=https://myimmichinstance.com
IMMICH_API_KEY=eggnogisgood212121
```

The second file is `hooks.json` and should contain the webhook URLs and their corresponding API keys in the following format:

```json
[
	{
		"url": "http://example.com",
		"key": "thisisakey"
	}
]
```

## Running the Program

My recommendation is to use either docker or docker compose. If you choose to use docker you can simply run it as

```bash
docker run \
	--env-file .env \
	-v /path/to/hooks.json:/hooks.json \
	-v immich_hooks_data:/data/ \
	ion606:immich-webhook-poller
```

(Make sure to create the volume first)

If you want to use compose, create a service with

```yml
services:
  immich-poller:
    image: ion606/immich-webhook-poller:latest
    env_file: .env

    # if you want persistance
    volumes:
      - immich_hooks_data:/data

# if you want persistance
volumes:
  immich_hooks_data:
```
