"""
Unit tests for the v2ray TUI application modules.
"""

import unittest
import tempfile
import os
from pathlib import Path

from config_manager import parse_vless_uri, parse_mihomo_json_config
from system_proxy_manager import set_system_proxy, get_system_proxy_status
from logging_manager import LogManager, get_recent_logs
from subscription_manager import SubscriptionManager
from geo_update_manager import GeoUpdateManager


class TestConfigManager(unittest.TestCase):
    """Tests for the config manager module."""
    
    def test_parse_vless_uri(self):
        """Test parsing a VLESS URI."""
        uri = "vless://12345678-1234-1234-1234-123456789012@demo.com:443?encryption=none&security=tls&type=ws&host=demo.com&path=%2Fpath#Demo"
        config = parse_vless_uri(uri)
        
        self.assertIsNotNone(config)
        self.assertEqual(config['uuid'], '12345678-1234-1234-1234-123456789012')
        self.assertEqual(config['server'], 'demo.com')
        self.assertEqual(config['port'], 443)
        self.assertEqual(config['remark'], 'Demo')
    
    def test_parse_mihomo_json_config(self):
        """Test parsing a JSON configuration."""
        json_str = '{"protocol": "vless", "server": "example.com", "port": 443, "tag": "example"}'
        config = parse_mihomo_json_config(json_str)
        
        self.assertIsNotNone(config)
        self.assertEqual(config['protocol'], 'vless')


class TestSystemProxyManager(unittest.TestCase):
    """Tests for the system proxy manager module."""
    
    def test_get_system_proxy_status(self):
        """Test getting system proxy status."""
        status = get_system_proxy_status()
        self.assertIsInstance(status, str)


class TestLoggingManager(unittest.TestCase):
    """Tests for the logging manager module."""
    
    def test_log_manager_creation(self):
        """Test creating a log manager instance."""
        with tempfile.TemporaryDirectory() as temp_dir:
            log_manager = LogManager(log_dir=temp_dir)
            logger = log_manager.get_logger()
            
            # Test that logger works
            logger.info("Test log message")
            
            # Check that recent logs can be retrieved
            recent_logs = get_recent_logs()
            self.assertIsInstance(recent_logs, list)


class TestSubscriptionManager(unittest.TestCase):
    """Tests for the subscription manager module."""
    
    def test_subscription_manager_creation(self):
        """Test creating a subscription manager instance."""
        with tempfile.NamedTemporaryFile(delete=False, suffix='.json') as tmp_file:
            tmp_file.close()  # Close the file so it can be opened by the manager
            
            try:
                sub_manager = SubscriptionManager(subscription_file=tmp_file.name)
                
                # Test adding a subscription
                result = sub_manager.add_subscription("Test Sub", "https://example.com/sub")
                self.assertTrue(result)
                
                # Test getting subscription list
                subs = sub_manager.get_subscription_list()
                self.assertEqual(len(subs), 1)
                self.assertEqual(subs[0]['name'], "Test Sub")
                
            finally:
                # Clean up
                os.unlink(tmp_file.name)


class TestGeoUpdateManager(unittest.TestCase):
    """Tests for the geo update manager module."""
    
    def test_geo_update_manager_creation(self):
        """Test creating a geo update manager instance."""
        geo_manager = GeoUpdateManager(mihomo_home="./test_mihomo")
        
        # Check that paths are set correctly
        geoip_path, geosite_path = geo_manager.get_geo_database_paths()
        self.assertEqual(geoip_path, Path("./test_mihomo/geoip.dat"))
        self.assertEqual(geosite_path, Path("./test_mihomo/geosite.dat"))
        
        # Check database status (they probably don't exist, but method should work)
        status = geo_manager.check_existing_databases()
        self.assertIn('geoip', status)
        self.assertIn('geosite', status)


if __name__ == '__main__':
    unittest.main()