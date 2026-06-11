using Microsoft.Data.SqlClient;
using System.Diagnostics;

var builder = WebApplication.CreateBuilder(args);
 
// Add Swagger services
 
builder.Services.AddEndpointsApiExplorer();
 
builder.Services.AddSwaggerGen();
 
var app = builder.Build();
 
// Configure Swagger
 
app.UseSwagger();
 
app.UseSwaggerUI();
 
app.UseHttpsRedirection();
 
var summaries = new[]
{
    "Freezing",
    "Bracing",
    "Chilly",
    "Cool",
    "Mild",
    "Warm",
    "Balmy",
    "Hot",
    "Sweltering",
    "Scorching"
};
 
app.MapGet("/weatherforecast", () =>
{
    var forecast = Enumerable.Range(1, 5).Select(index =>
        new WeatherForecast
        (
            DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
            Random.Shared.Next(-20, 55),
            summaries[Random.Shared.Next(summaries.Length)]
        ))
        .ToArray();
 
    return forecast;
})
.WithName("GetWeatherForecast");

app.MapGet("/user", async (HttpContext context) =>
{
    string? id = context.Request.Query["id"];
 
    string connectionString =

        "Server=localhost;Database=TestDb;Trusted_Connection=True;";
 
    string query =
        "SELECT * FROM Users WHERE Id = " + id;
 
    try
    {
        using var connection = new SqlConnection(connectionString);
 
        using var command =
            new SqlCommand(query, connection);
 
        await connection.OpenAsync();
 
        using var reader =
            await command.ExecuteReaderAsync();
 
        while (await reader.ReadAsync())
        {
            await context.Response.WriteAsync(
                reader["Name"].ToString() + "\n");
        }
    }
    catch (Exception ex)
    {
        context.Response.StatusCode = 500;
 
        await context.Response.WriteAsync(
            "Error: " + ex.Message);
    }
});

app.MapGet("/file", (string fileName) =>
{
    return System.IO.File.ReadAllText(fileName);
});

app.MapGet("/download", (string fileName) =>
{
    var filePath = Path.Combine("uploads", fileName);
 
    return System.IO.File.ReadAllText(filePath);
});

app.Run();
 
record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}