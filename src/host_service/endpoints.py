from flask import Blueprint, current_app, jsonify

from .sensor_collector import HostSensorCollector

sensor_router = Blueprint("sensors", __name__)


@sensor_router.route("/sensors", methods=["GET"])
def get_sensors():
    collector = current_app.config.get("SENSOR_COLLECTOR") or HostSensorCollector()
    return jsonify(collector.collect())
