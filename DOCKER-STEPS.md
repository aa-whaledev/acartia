# Local Setup
As we work through improving and modernizing the tech stack, the current setup requires
outdated dependencies to continue to run the tools. Hence, would require Docker to mimic
the setup instead of downgrading node and other dependencies on your local computer.

# Build local frontend with external env file
````
docker build -f Dockerfile.frontend -t acartia-frontend .
docker run -p 8080:8080 --env-file .env.frontend acartia-frontend
````

First time running the docker build command may take sometime but once it works and finishes building, you should be able
to run the `docker run..` command above and observe the site from `localhost:8080` in your browser.
