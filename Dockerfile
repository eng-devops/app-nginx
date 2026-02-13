# Build da imagem para app-nginx
# Uso: docker build -t app-nginx:latest .
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

