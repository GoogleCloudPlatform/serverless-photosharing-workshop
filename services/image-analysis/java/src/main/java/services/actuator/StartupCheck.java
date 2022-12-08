package services.actuator;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.springframework.boot.actuate.endpoint.annotation.Endpoint;
import org.springframework.boot.actuate.endpoint.annotation.ReadOperation;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;

@Component
@Endpoint(id="startup")
public class StartupCheck {
    // logger
    private static final Log logger = LogFactory.getLog(StartupCheck.class);

    private static boolean status = false;

    public static void up(){ status = true;}
    public static void down(){ status = false;}

    @ReadOperation
    public CustomData customEndpoint() {
        Map<String, Object> details = new LinkedHashMap<>();
        if (!status) {
            logger.info("ImageAnalysisApplication Startup Endpoint: Application is ready to serve traffic !");
            return null;
        }

        logger.info("ImageAnalysisApplication Startup Endpoint: Application is ready to serve traffic !");

        CustomData data = new CustomData();
        details.put("StartupEndpoint", "ImageAnalysisApplication Startup Endpoint: Application is ready to serve traffic");
        data.setData(details);

        return data;
    }
}