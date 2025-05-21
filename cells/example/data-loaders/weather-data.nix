{
  inputs,
  cell,
}: {
  name = "weather-data";
  system = "x86_64-linux";
  description = "Load daily weather data from OpenWeatherMap API";
  
  source = {
    type = "api";
    location = "https://api.openweathermap.org/data/2.5/weather";
    options = {
      header = "Authorization: Bearer $OPENWEATHERMAP_API_KEY";
      query = "q=London,uk&units=metric";
    };
  };
  
  destination = {
    dataset = "data/weather/daily.json";
    format = "json";
  };
  
  transform = {
    type = "jq";
    query = "{ date: now | strftime(\"%Y-%m-%d\"), temp: .main.temp, humidity: .main.humidity, pressure: .main.pressure, wind_speed: .wind.speed, description: .weather[0].description }";
  };
  
  schedule = {
    cron = "0 6 * * *";  # Every day at 6 AM
    timezone = "UTC";
  };
  
  dependencies = [];
}