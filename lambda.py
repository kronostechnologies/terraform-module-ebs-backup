import boto3
import os
import datetime
import time

ec2 = boto3.client('ec2')
volume_tag_namespace = os.environ['LAMBDA_VOLUME_TAG_NAMESPACE']
lambda_arn = os.environ['LAMBDA_ARN']

def lambda_handler(event, context):

    def find_all_eligible_volumes():
        print('Searching for volume with tag "%s"' % volume_tag_namespace)
        paginator = ec2.get_paginator('describe_volumes')
        iterator = paginator.paginate(
            Filters=[{'Name': 'tag:%s' % volume_tag_namespace, 'Values': ['yes', 'true', '1', 'y']}],
            DryRun=False
        )
        volumes = []
        for page in iterator:
            volumes.extend(page['Volumes'])

        return volumes

    def snapshot_volume(volume):
            instance_id = volume['Attachments']['InstanceId']
            instance_tags = ec2.describe_tags(Filters=[{'Name': 'resource-id', 'Values': [instance_id]}])
            instance_name = find_tag(instance_tags, 'Name')

            volume_id = volume['VolumeId']
            volume_name = find_tag(volume, 'Name')

            print("Found EBS volume %s (%s) on instance %s (%s), creating snapshot" % (volume_name, volume_id, instance_name, instance_id))

            snapshot = ec2.create_snapshot(
                Description="%s from instance %s (%s)" % (volume_name or volume_id, instance_name, instance_id),
                VolumeId=volume_id,
            )

            today_string = datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M")

            snapshot_name = "%s %s" % (volume_name or volume_id, today_string)
            snapshot_tags = [
                {'Key': 'Name', 'Value': snapshot_name},
                {'Key': 'EbsBackup_InstanceId', 'Value': instance_id},
                {'Key': 'EbsBackup_InstanceName', 'Value': instance_name},
                {'Key': 'EbsBackup_VolumeName', 'Value': volume_name},
                {'Key': 'EbsBackup_DeviceName', 'Value': volume['Attachments']['Device']},
                {'Key': 'EbsBackup_Datetime', 'Value': today_string},
                {'Key': 'EbsBackup_Timestamp', 'Value': time.time()},
                {'Key': 'EbsBackup_LambdaARN', 'Value': lambda_arn},
            ]

            ec2.create_tags(
                Resources=[snapshot['SnapshotId']],
                Tags=snapshot_tags,
            )

    def find_tag(object_with_tags, tag_name):
        for tag in object_with_tags['Tags']:
            if tag['Key'] == tag_name:
                return tag["Value"]
        return nil

    volumes = find_all_eligible_volumes()
    for volume in volumes:
        snapshot_volume(volume)