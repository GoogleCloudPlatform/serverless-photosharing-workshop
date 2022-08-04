package services;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.boot.test.context.SpringBootTest;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.Before;
import org.json.JSONException;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.junit4.SpringRunner;
import org.springframework.test.web.servlet.MockMvc;

@RunWith(SpringRunner.class)
@SpringBootTest
@AutoConfigureMockMvc
public class ImageAnalysisApplicationTests {

	@Test
	public void contextLoads() {
	}

	@Autowired private MockMvc mockMvc;
	String mockBody;
  
	@Before
	public void setup() throws JSONException {
	  JSONObject message =
		  new JSONObject()
			  .put("data", "dGVzdA==")
			  .put("messageId", "91010751788941")
			  .put("publishTime", "2017-09-25T23:16:42.302Z")
			  .put("attributes", new JSONObject());
	  mockBody = new JSONObject().put("message", message).toString();
	}
  
	@Test
	public void addEmptyBody() throws Exception {
	  mockMvc.perform(post("/")).andExpect(status().isBadRequest());
	}
  
	@Test
	public void addNoMessage() throws Exception {
	  mockMvc
		  .perform(post("/").contentType(MediaType.APPLICATION_JSON).content("{}"))
		  .andExpect(status().isBadRequest());
	}
  
	@Test
	public void addInvalidMimetype() throws Exception {
	  mockMvc
		  .perform(post("/").contentType(MediaType.TEXT_HTML).content(mockBody))
		  .andExpect(status().isUnsupportedMediaType());
	}
  
	@Test
	public void addRequiredHeaders() throws Exception {
	  mockMvc
		  .perform(
			  post("/")
				  .contentType(MediaType.APPLICATION_JSON)
				  .content(mockBody)
				  .header("ce-id", "test")
				  .header("ce-source", "test")
				  .header("ce-type", "test")
				  .header("ce-specversion", "test")
				  .header("ce-subject", "test"))
		  .andExpect(status().is4xxClientError());
	}
  
	@Test
	public void missingRequiredHeaders() throws Exception {
	  mockMvc
		  .perform(
			  post("/")
				  .contentType(MediaType.APPLICATION_JSON)
				  .content(mockBody)
				  .header("ce-source", "test")
				  .header("ce-type", "test")
				  .header("ce-specversion", "test")
				  .header("ce-subject", "test"))
		  .andExpect(status().isBadRequest());
  
	  mockMvc
		  .perform(
			  post("/")
				  .contentType(MediaType.APPLICATION_JSON)
				  .content(mockBody)
				  .header("ce-id", "test")
				  .header("ce-source", "test")
				  .header("ce-type", "test")
				  .header("ce-specversion", "test"))
		  .andExpect(status().isBadRequest());
	}
}
