# project-devops-deploy

Build:
./gradlew clean build
cd frontend && make install && make build

Docker:
docker build -t project-devops-deploy:local .
docker run --rm -p 8080:8080 project-devops-deploy:local

Registry:
echo "$GHCR_TOKEN" | docker login ghcr.io -u username --password-stdin
docker tag project-devops-deploy:local ghcr.io/mazzahaker/project-devops-deploy:latest
docker push ghcr.io/mazzahaker/project-devops-deploy:latest

Kubernetes:
kubectl apply -f k8s/

Helm:
helm upgrade --install bulletin helm/bulletin-board -n bulletin --create-namespace
