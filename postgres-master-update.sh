#!/bin/bash
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
stamp=$(date +"%Y_%m_%d_%I_%M_%p")
filename="$stamp-primary"
POD_NAMES=("postgres-0" "postgres-1" "postgres-2")
# Loop through each pod name
for POD_NAME in "${POD_NAMES[@]}"; do
    # Execute the kubectl command to retrieve logs, extract the monitoring cluster primary, and change the post
    PRIMARY=$(/usr/local/bin/kubectl logs "$POD_NAME" -n postgres | grep "monitoring cluster primary" | awk '{print $7}' | tr -d '"')
      
    # Check if PRIMARY is not empty
    if [ -n "$PRIMARY" ]; then
        echo "Primary  found in pod: $POD_NAME"
        break  # Exit the loop when primary is found        
    fi
done

# Get the name of the current pod
CURRENT_POD_NAME="$PRIMARY"

# Get the name of the existing pod in the service selector
EXISTING_POD_NAME=$(/usr/local/bin/kubectl get svc master-headless-svc -n postgres -o=jsonpath='{.spec.selector.statefulset\.kubernetes\.io/pod-name}')

# Check if the current pod name matches the existing pod name
if [ "$CURRENT_POD_NAME" == "$EXISTING_POD_NAME" ]; then
    echo "$stamp : Pod name matches the existing pod name. No action needed." >>/home/ubuntu/scripts/logs/access.log 
else
    if [ "$CURRENT_POD_NAME" != "" ]; then
	    # Update the service with the new pod name
	    /usr/local/bin/kubectl patch svc master-headless-svc -n postgres -p '{"spec": {"selector": {"statefulset.kubernetes.io/pod-name": "'"$CURRENT_POD_NAME"'"}}}'
	    echo "Service updated with the new pod name: $CURRENT_POD_NAME" > /home/ubuntu/scripts/logs/${filename}.change

        # Getting Completed Pod Name & Deleting it
        COMPLETED_POD=$(kubectl get pod -n postgres | grep Completed | awk '{print $1}')
        kubectl get pod -n postgres | grep Completed | awk '{print $1}' | xargs -I {} kubectl delete pod {} -n postgres
        echo "Deleted the Completed Postgres Pod: $COMPLETED_POD"
        
    else 
    	echo "there is not active primary" /home/ubuntu/scripts/logs/${filename}.noprimary
   fi 	
fi
