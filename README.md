# Kartik Jagdale's Blog

Personal github website to publish technical and non-technical blogs.

The project is being hosted on <https://kartikjagdale.github.io/>

Please have a look!

# My Jekyll Blog

This is a simple Jekyll blog project that can be run locally using Docker and Docker Compose.

## Prerequisites

Make sure you have the following installed on your machine:

- Docker
- Docker Compose

## Getting Started

To run the Jekyll blog locally, follow these steps:

1. Clone the repository to your local machine:

   ```
   git clone <repository-url>
   cd my-jekyll-blog
   ```

2. Build and start the Docker containers:

   ```
   docker-compose up
   ```

3. Open your web browser and navigate to `http://localhost:4000` to view your Jekyll blog.

## Live Reloading

The Docker Compose setup includes live reloading. Any changes you make to the source files will automatically refresh the browser.

## Project Structure

- `_config.yml`: Configuration settings for the Jekyll site.
- `_posts/`: Directory containing blog posts.
- `_layouts/`: Directory containing layout templates.
- `Dockerfile`: Instructions to build the Docker image for the Jekyll blog.
- `docker-compose.yml`: Defines services and configurations for Docker.
- `Gemfile`: Lists required Ruby gems for the Jekyll site.
- `Gemfile.lock`: Locks the versions of the gems specified in the Gemfile.

## Contributing

Feel free to submit issues or pull requests for improvements or bug fixes.