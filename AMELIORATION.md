Apres l'install des pods postgres et api faire ca:

podman exec vocalyx-api-01 python -c "from database import init_db; init_db()"
podman exec vocalyx-postgres psql -U vocalyx -d vocalyx_db -c "\dt"
