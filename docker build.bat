cd ..
cd .\Documents\GitHub\acartia
docker build -f Dockerfile.frontend -t acartia-frontend .
docker run -p 8080:8080 --env-file .env.frontend acartia-frontend
pause
pause