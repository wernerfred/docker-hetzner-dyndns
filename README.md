![GitHub Workflow Status](https://img.shields.io/github/workflow/status/wernerfred/docker-hetzner-dyndns/Build%20current%20version%20+%20push%20to%20DockerHub?label=Docker%20Build)
![Docker Pulls](https://img.shields.io/docker/pulls/wernerfred/docker-hetzner-dyndns?label=Docker%20Pulls)
![GitHub](https://img.shields.io/github/license/wernerfred/docker-hetzner-dyndns?label=License)
![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/wernerfred/docker-hetzner-dyndns?label=Image%20Size)
![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/wernerfred/docker-hetzner-dyndns?label=Latest%20Release)
![Docker Image Version (latest semver)](https://img.shields.io/docker/v/wernerfred/docker-hetzner-dyndns?label=Latest%20Image)
![GitHub Release Date](https://img.shields.io/github/release-date/wernerfred/docker-hetzner-dyndns?label=Release%20Date)

# docker-hetzner-dyndns

This project aims to provide a standalone container that dynamically updates the assigned public IP of its ISP connection for a record managed by [Hetzner DNS Console](https://www.hetzner.com/de/dns-console).

## Installation

### Build from source

To build this project from source make sure to clone this repository from github and run the following command:

```
docker build -t wernerfred/docker-hetzner-dyndns .
```

### Pull from Docker Hub

You can directly pull the latest release from the [Docker Hub repository](https://hub.docker.com/r/wernerfred/docker-hetzner-dyndns/):

```
docker pull wernerfred/docker-hetzner-dyndns
```

## Usage

To run the container you can use `docker run`. You might adjust the following command according to your needs:

```
docker run -d \
           wernerfred/docker-hetzner-dyndns
```

### Configuration

The following environment variables can be used to configure the container:

| Variable                | Default | Description | Example |
|-------------------------|---------|-------------|---------|
| `RECORD_NAME`           |         | The DNS record nameto use  | `home` |
| `RECORD_TYPE`           |         | The DNS record type to use | `A`    |
| `ZONE_ID`               |         | The DNS zone id            | `123456abcde7890` |
| `SLEEP_INTERVAL`        | `60`    | The interval to sleep between checks | `120` |	
| `HETZNER_DNS_API_TOKEN` |         | The Hetzner DNS Console API token | `ab12345cdefgh67890ijklmn` |

Simply add the  environment variables you want to change to your `docker run` command:

```
docker run -d \
           -e RECORD_NAME=<name> \
           -e RECORD_TYPE=<type> \
           -e ZONE_ID=<id> \
           -e HETZNER_DNS_API_TOKEN=<token> \
           -e SLEEP_INTERVAL=<interval>
           wernerfred/docker-hetzner-dyndns
```