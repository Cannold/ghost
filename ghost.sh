#!/bin/bash

CMD=$1
shift

case $CMD in
    run)
        docker-compose up -d
        docker-compose logs -f
        ;;

    setup)
        docker-compose run --rm app perl /app/bin/setup-integration-service.pl
        ;;

    import)
        ./bin/post-to-ghost.sh
        ;;

    stop)
        docker-compose down --remove-orphans
        ;;

    mysql)
        docker-compose exec db mysql -pawesomepassword
        ;;

    *)
        echo "usage: $0 [run|stop|mysql|setup|import]"
        exit 1
        ;;
esac
