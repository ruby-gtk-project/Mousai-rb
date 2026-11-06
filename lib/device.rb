# frozen_string_literal: true

require "gstreamer"

module Mousai
  # Looks up the default audio source or sink device.
  #
  # Ported from upstream's src/device.rs: `DeviceClass` (`Audio/Source` or
  # `Audio/Sink`) and `find_default`, which asks the `pulsedeviceprovider` for
  # its devices and returns the one that both belongs to the wanted class and
  # has `is-default` set — raising, as upstream's `Result` does, when the
  # provider is missing or no such device turns up.
  class Device
    class Error < StandardError; end

    SOURCE = "Audio/Source"
    SINK = "Audio/Sink"

    # The `gst::Device` found, or raises `Device::Error`.
    def self.find_default(device_class)
      provider.then do |provider|
        provider.start.then do |started|
          unless started
            raise Error, "Failed to start the pulse device provider"
          end
        end

        provider.devices.find { |device| default_of_class?(device, device_class) }.tap do
          provider.stop
        end || raise(Error, "Failed to find a default device")
      end
    end

    def self.provider
      Gst::DeviceProviderFactory.find("pulsedeviceprovider")&.get ||
        raise(Error, "No pulse device provider")
    end
    private_class_method :provider

    def self.default_of_class?(device, device_class)
      device.has_classes?(device_class) && default_property?(device)
    end
    private_class_method :default_of_class?

    def self.default_property?(device)
      device.properties&.get_value("is-default") == true
    end
    private_class_method :default_property?
  end
end
