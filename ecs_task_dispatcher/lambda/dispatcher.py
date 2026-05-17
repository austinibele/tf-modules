import json
import logging
import os
import re
from typing import Any

import boto3


logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

ecs = boto3.client("ecs")


def _required_string(payload: dict[str, Any], key: str) -> str:
    value = payload.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing required string field: {key}")
    return value.strip()


def _task_family_from_arn(task_definition_arn: str) -> str:
    match = re.search(r":task-definition/([^:]+):\d+$", task_definition_arn)
    if not match:
        raise ValueError(f"Unexpected task definition ARN: {task_definition_arn}")
    return match.group(1)


def _resolve_latest_active_task_definition(family: str) -> str:
    paginator = ecs.get_paginator("list_task_definitions")
    for page in paginator.paginate(familyPrefix=family, status="ACTIVE", sort="DESC"):
        for task_definition_arn in page.get("taskDefinitionArns", []):
            if _task_family_from_arn(task_definition_arn) == family:
                described = ecs.describe_task_definition(taskDefinition=task_definition_arn)
                task_definition = described["taskDefinition"]
                if task_definition.get("status") != "ACTIVE":
                    continue
                return task_definition["taskDefinitionArn"]

    raise RuntimeError(f"No ACTIVE task definition found for family {family}")


def _network_configuration(payload: dict[str, Any]) -> dict[str, Any]:
    network = payload.get("network_configuration")
    if not isinstance(network, dict):
        raise ValueError("Missing required object field: network_configuration")

    subnets = network.get("subnets")
    security_groups = network.get("security_groups")
    if not isinstance(subnets, list) or not all(isinstance(v, str) and v for v in subnets):
        raise ValueError("network_configuration.subnets must be a non-empty string list")
    if not isinstance(security_groups, list) or not all(
        isinstance(v, str) and v for v in security_groups
    ):
        raise ValueError("network_configuration.security_groups must be a non-empty string list")

    assign_public_ip = network.get("assign_public_ip", False)
    if isinstance(assign_public_ip, bool):
        assign_public_ip_value = "ENABLED" if assign_public_ip else "DISABLED"
    elif assign_public_ip in ("ENABLED", "DISABLED"):
        assign_public_ip_value = assign_public_ip
    else:
        raise ValueError("network_configuration.assign_public_ip must be boolean or ENABLED/DISABLED")

    return {
        "awsvpcConfiguration": {
            "subnets": subnets,
            "securityGroups": security_groups,
            "assignPublicIp": assign_public_ip_value,
        }
    }


def _started_by(job_name: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_-]", "-", job_name)
    return cleaned[:36] or "ecs-task-dispatcher"


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    logger.info("Received ECS task dispatch request: %s", json.dumps(event, sort_keys=True))

    job_name = _required_string(event, "job_name")
    cluster_arn = _required_string(event, "cluster_arn")
    task_definition_family = _required_string(event, "task_definition_family")
    task_definition_arn = _resolve_latest_active_task_definition(task_definition_family)

    run_task_args: dict[str, Any] = {
        "cluster": cluster_arn,
        "taskDefinition": task_definition_arn,
        "count": int(event.get("task_count", 1)),
        "networkConfiguration": _network_configuration(event),
        "startedBy": _started_by(job_name),
    }

    launch_type = event.get("launch_type", "FARGATE")
    if launch_type:
        run_task_args["launchType"] = launch_type

    platform_version = event.get("platform_version")
    if platform_version:
        run_task_args["platformVersion"] = platform_version

    group = event.get("group")
    if group:
        run_task_args["group"] = str(group)

    overrides = event.get("overrides")
    if overrides:
        if not isinstance(overrides, dict):
            raise ValueError("overrides must be an object when provided")
        run_task_args["overrides"] = overrides

    if "enable_execute_command" in event:
        run_task_args["enableExecuteCommand"] = bool(event["enable_execute_command"])
    if "enable_ecs_managed_tags" in event:
        run_task_args["enableECSManagedTags"] = bool(event["enable_ecs_managed_tags"])

    response = ecs.run_task(**run_task_args)
    failures = response.get("failures", [])
    if failures:
        logger.error(
            "ECS RunTask failed for job %s with task definition %s: %s",
            job_name,
            task_definition_arn,
            json.dumps(failures, sort_keys=True),
        )
        raise RuntimeError(f"ECS RunTask failed for {job_name}: {failures}")

    task_arns = [task["taskArn"] for task in response.get("tasks", []) if "taskArn" in task]
    if not task_arns:
        logger.error("ECS RunTask returned no task ARNs for job %s", job_name)
        raise RuntimeError(f"ECS RunTask returned no task ARNs for {job_name}")

    result = {
        "job_name": job_name,
        "cluster_arn": cluster_arn,
        "task_definition_arn": task_definition_arn,
        "task_arns": task_arns,
    }
    logger.info("Dispatched ECS task successfully: %s", json.dumps(result, sort_keys=True))
    return result
