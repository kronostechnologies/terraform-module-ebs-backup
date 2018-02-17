import boto3
import os
import datetime
import time

ec2 = boto3.client('ec2')
volume_tag_namespace = os.environ['LAMBDA_VOLUME_TAG_NAMESPACE']

def lambda_handler(event, context):

    lambda_arn = context.invoked_function_arn
    lambda_function_name = context.function_name
    lambda_function_version = context.function_version

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
            instance_id = volume['Attachments'][0]['InstanceId']
            instance_tags = ec2.describe_tags(Filters=[{'Name': 'resource-id', 'Values': [instance_id]}])
            instance_name = find_tag(instance_tags, 'Name')

            volume_id = volume['VolumeId']
            volume_name = find_tag(volume, 'Name')

            print("Found EBS volume %s (%s) on instance %s (%s)" % (volume_name, volume_id, instance_name, instance_id))

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
                {'Key': 'EbsBackup_DeviceName', 'Value': volume['Attachments'][0]['Device']},
                {'Key': 'EbsBackup_DatetimeUTC', 'Value': today_string},
                {'Key': 'EbsBackup_Timestamp', 'Value': str(time.time())},
                {'Key': 'EbsBackup_LambdaARN', 'Value': lambda_arn},
                {'Key': 'EbsBackup_LambdaFunctionName', 'Value': lambda_function_name},
                {'Key': 'EbsBackup_LambdaFunctionVersion', 'Value': lambda_function_version},
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