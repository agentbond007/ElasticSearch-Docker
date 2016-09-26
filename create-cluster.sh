#!/usr/bin/env bash
#
# Create a Swarm Mode cluster with a single master and a configurable number of workers

workers=${WORKERS:-"worker1 worker2"}

#######################################
# Creates a machine on Digital Ocean
# Globals:
#   DO_ACCESS_TOKEN The token needed to access DigitalOcean's API
# Arguments:
#   $1 the actual name to give to the machine
#######################################
create_machine() {
  docker-machine create \
    -d digitalocean \
    --digitalocean-access-token=$DO_ACCESS_TOKEN \
    --digitalocean-size 2gb \
    $1
}

#######################################
# Executes a command on the specified machine
# Arguments:
#   $1     The machine on which to run the command
#   $2..$n The command to execute on that machine
#######################################
machine_do() {
  docker-machine ssh $@
}

main() {

  if [ -z "$DO_ACCESS_TOKEN" ]; then
    echo "Please export a DigitalOcean Access token: https://cloud.digitalocean.com/settings/api/tokens/new"
    echo "export DO_ACCESS_TOKEN=<yourtokenhere>"
    exit 1
  fi

  if [ -z "$WORKERS" ]; then
    echo "You haven't provided your workers by setting the \$WORKERS environment variable, using the default ones: $workers"
  fi

  # Create the first and only master
  echo "Creating the master"

  create_machine master1

  master_ip=$(docker-machine ip master1)

  # Initialize the swarm mode on it
  echo "Initializing the swarm mode"
  machine_do master1 docker swarm init --advertise-addr $master_ip

  # Obtain the token to allow workers to join
  worker_tkn=$(machine_do master1 docker swarm join-token -q worker)
  echo "Worker token: ${worker_tkn}"

  # Create and join the workers
  for worker in $workers; do
    echo "Creating worker ${worker}"
    create_machine $worker
    machine_do $worker docker swarm join --token $worker_tkn $master_ip:2377
  done
}

main $@
