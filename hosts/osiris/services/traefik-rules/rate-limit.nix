{
  services.traefik.dynamicConfigOptions.http.middlewares = {
    middlewares-rate-limit.rateLimit = {
      average = 200;
      period = "1s";
      burst = 400;
    };
  };
}
