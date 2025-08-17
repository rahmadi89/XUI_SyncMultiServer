import urllib3
import requests
import sqlite3
import json
import logging
import traceback
import os
from logging.handlers import RotatingFileHandler

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

logger = logging.getLogger()
logger.setLevel(logging.INFO)

formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")

script_dir = os.path.dirname(os.path.abspath(__file__))
log_file_path = os.path.join(script_dir, "XUI_SyncMultiServer.log")

file_handler = RotatingFileHandler(log_file_path, maxBytes=30*1024*1024, backupCount=5)
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

console_handler = logging.StreamHandler()
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)


def login_to_server(base_url: str, username: str, password: str):
    session = requests.Session()
    login_url = f"{base_url.rstrip('/')}/login"
    payload = {
        "username": username,
        "password": password
    }
    try:
        resp = session.post(login_url, data=payload, verify=False)
        resp.raise_for_status()
        logger.info(f"[+] Logged in successfully: {username}@{base_url}")
        #logging.info("[+] Cookies:", session.cookies.get_dict())
    except Exception as e:
        logger.error(f"[!] Login failed for {username}@{base_url}: {e}")
        raise

    return session

def download_server_db(session, base_url: str, filename : str):
    """
    Download DB from x-ui Panel
    :param session: logined session
    :param base_url: base url for example https://example.com:12345/shXW7lGvV2pArAg)
    :param filename: path to save db
    """
    url = f"{base_url.rstrip('/')}/server/getDb" 
    try:
        resp = session.get(url, verify=False)
        resp.raise_for_status()
        with open(filename, "wb") as f:
            f.write(resp.content)
        logging.info(f"[+] Database saved as {filename}")
    except Exception as e:
        logger.error(f"[!] Failed to download DB from {base_url}: {e}")
        raise



def load_server_configs(config_path):
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        logger.error(f"[!] Config file not found: {config_path}")
        raise
    except json.JSONDecodeError as e:
        logger.error(f"[!] Failed to parse JSON in {config_path}: {e}")
        raise


    servers = []
    for i, server_info in enumerate(data, start=1):
        try:
            servers.append({
                "name": server_info["name"],
                "base_url": server_info["base_url"],
                "user" : server_info["user"],
                "pass" : server_info["pass"],
                "db_file": f"downloaded{i}.db"
            })
        except KeyError as e:
            logger.warning(f"[!] Missing key {e} in server entry {i}, skipping this server.")
            continue
    
    if not servers:
        logger.error("[!] No valid server entries found in config.")
        raise ValueError("No valid servers to process.")
    
    return servers

def sync_clients_traffics(downloaded_db_path, local_cursor):
    try:
        with sqlite3.connect(downloaded_db_path) as remote_conn:
            remote_cursor = remote_conn.cursor()

            remote_cursor.execute("SELECT email, down, up, total FROM client_traffics")
            remote_client_data = remote_cursor.fetchall()


            for email, remote_down, remote_up, remote_total in remote_client_data:
                updates_client_traffics = []
                updates_inbounds = []
                local_cursor.execute("SELECT down, up, total, inbound_id FROM client_traffics WHERE email = ?", (email,))
                local_client_data = local_cursor.fetchone()
                
                if local_client_data is None:
                    continue

                down_local, up_local, total_local, current_client_inbound_id  = local_client_data

                local_client_data_changed = False
                
                if remote_down > down_local:
                    updates_client_traffics.append(("down", remote_down, email))
                    local_client_data_changed = True

                if remote_up > up_local:
                    updates_client_traffics.append(("up", remote_up, email))
                    local_client_data_changed = True

                if remote_total > total_local and total_local != 0:
                    updates_client_traffics.append(("total", remote_total, email))
                    local_client_data_changed =True

                local_cursor.execute("SELECT settings FROM inbounds WHERE id = ?",(current_client_inbound_id,))
                inbound_settings = local_cursor.fetchone()

                inbound_settings_changed = False
                if inbound_settings:
                    setting_json = inbound_settings[0]
                    inbound_settings = json.loads(setting_json)
                    
                    for client in inbound_settings.get("clients", []):
                        if client.get("email") == email:
                            total_final = total_local
                            if remote_total > total_local and total_local != 0:
                                total_final = remote_total
                                inbound_settings_changed = True
                                client["totalGB"] = total_final
                            if (remote_up + remote_down) > total_final and total_final != 0:
                                client["enable"] = False
                                inbound_settings_changed = True

                    updates_inbounds.append((json.dumps(inbound_settings),current_client_inbound_id))

                # Commit to local db
                with local_cursor.connection:
                    if local_client_data_changed:
                        for column, value, email in updates_client_traffics:
                            local_cursor.execute(
                                f"UPDATE client_traffics SET {column} = ? WHERE email = ?",
                                (value, email)
                            )
                    if inbound_settings_changed:
                        local_cursor.executemany(
                            "UPDATE inbounds SET settings = ? WHERE id = ?",
                            updates_inbounds
                        )

                logger.info(f"[+] Synced clients from {downloaded_db_path}")
    except Exception as e:
        logger.error(f"[!] Failed to sync clients from {downloaded_db_path}: {e}")
        logger.error(traceback.format_exc())
        raise




def main_sync():
    logger.info("[+] Script started")
    
    servers = load_server_configs("servers.json")
    local_db_path = "/etc/x-ui/x-ui.db"

    try:
        with sqlite3.connect(local_db_path) as conn_local:
            cursor_local = conn_local.cursor()

            for server in servers:
                try:
                    logging.info(f"[+] Processing {server['name']}...")
                    session = login_to_server(server["base_url"], server["user"], server["pass"])
                    download_server_db(session, server["base_url"], server["db_file"])
                    sync_clients_traffics(server["db_file"], cursor_local)         
                except Exception as e:
                    logger.error(f"[!] Error processing {server['name']}: {e}")
                    logger.error(traceback.format_exc())

        logger.info("[+] Script finished successfully")

    except Exception as e:
        logger.error(f"[!] Main loop error: {e}")
        logger.error(traceback.format_exc())


if __name__ == "__main__":
    main_sync()