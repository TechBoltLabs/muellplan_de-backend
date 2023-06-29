# muellplan_de-backend

> the backend for muellplan.de - a website/app where the next collection dates for different litter types can be checked (region Landshut in Bavaria).

## setup

### prerequisites
this backend needs an instance of mariadb running, which can be initialized with the file 'initialize_db.sql' from the frontend repository [muellplan_de](https://github.com/TechBoltLabs/muellplan_de).

### Docker

1. set up a docker image with the following command:

```bash
docker build -t muellplan_de-backend:latest .
```

2. adjust the file compose.yml to your needs and start the container with:

```bash
docker-compose up -d
```