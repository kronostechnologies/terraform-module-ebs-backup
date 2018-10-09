import boto3
import os
from datetime import datetime
from datetime import timedelta
from datetime import timezone

ec2 = boto3.client('ec2')
volume_tag_namespace = os.environ['LAMBDA_VOLUME_TAG_NAMESPACE']
backup_days_to_keep = os.environ['LAMBDA_BACKUP_DAYS_TO_KEEP']

def lambda_handler(event, context):

    def find_and_delete_all_eligible_snapshots():
        print('Searching for volumes with tag "%s"' % volume_tag_namespace)
        paginator = ec2.get_paginator('describe_volumes')
        volume_iterator = paginator.paginate(
            Filters=[{'Name': 'tag:%s' % volume_tag_namespace, 'Values': ['yes', 'true', '1', 'y']}],
            DryRun=False
        )
        for volume_page in volume_iterator:
            volumes = volume_page['Volumes']

            for volume in volumes:
                print('Searching for snapshot with volume id "%s"' % volume['VolumeId'])
                paginator = ec2.get_paginator('describe_snapshots')
                snapshot_iterator = paginator.paginate(
                    Filters=[{'Name': 'volume-id', 'Values': [volume['VolumeId']]}],
                    DryRun=False
                )
                for snapshot_page in snapshot_iterator:
                    snapshots = snapshot_page['Snapshots']
                    print('Deleting snapshots older than {days} days'.format(days=backup_days_to_keep))
                    for snapshot in snapshots:
                        delete_snapshot(snapshot)

    def delete_snapshot(snapshot):
        delete_time = datetime.utcnow() - timedelta(days=int(backup_days_to_keep))
        start_time = snapshot['StartTime'].replace(tzinfo=timezone.utc)
        delete_time = delete_time.replace(tzinfo=timezone.utc)

        if start_time < delete_time:
            print('Deleting {id}'.format(id=snapshot['SnapshotId']))
            snapshot.delete()

    find_and_delete_all_eligible_snapshots()
