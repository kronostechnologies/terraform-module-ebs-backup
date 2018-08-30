import boto3
import os
import datetime
import time

ec2 = boto3.client('ec2')
volume_tag_namespace = os.environ['LAMBDA_VOLUME_TAG_NAMESPACE']
backup_days_to_keep = os.environ['LAMBDA_BACKUP_DAYS_TO_KEEP']

def lambda_handler(event, context):

    lambda_arn = context.invoked_function_arn
    lambda_function_name = context.function_name
    lambda_function_version = context.function_version

    def find_all_eligible_snapshots():
        print('Searching for snapshot with tag "%s"' % volume_tag_namespace)
        paginator = ec2.get_paginator('describe_snapshots')
        iterator = paginator.paginate(
            Filters=[{'Name': 'tag:%s' % volume_tag_namespace, 'Values': ['yes', 'true', '1', 'y']}],
            DryRun=False
        )
        snapshots = []
        for page in iterator:
            snapshots.extend(page['Snapshots'])

        return snapshots

    def delete_snapshot(snapshot):
        delete_time = datetime.utcnow() - timedelta(days=backup_days_to_keep)
        print 'Deleting any snapshots older than {days} days'.format(days=backup_days_to_keep)
        start_time = datetime.strptime(
            snapshot.start_time,
	    '%Y-%m-%dT%H:%M:%S.000Z'
        )

        if start_time < delete_time:
	    print 'Deleting {id}'.format(id=snapshot.id)
	    snapshot.delete()

    snapshots = find_all_eligible_snapshots()
    for snapshot in snapshots:
        delete_snapshot(snapshot)
