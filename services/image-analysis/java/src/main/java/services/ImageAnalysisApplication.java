/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package services;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@SpringBootApplication
public class ImageAnalysisApplication {
	// private static final Log logger = LogFactory.getLog(ImageAnalysisApplication.class);
	private static final Logger logger = LoggerFactory.getLogger(ImageAnalysisApplication.class);

	public static void main(String[] args) {
		logger.info("ImageAnalysisApplication: Active processors: " + Runtime.getRuntime().availableProcessors()); 

		SpringApplication.run(ImageAnalysisApplication.class, args);
	}

}
