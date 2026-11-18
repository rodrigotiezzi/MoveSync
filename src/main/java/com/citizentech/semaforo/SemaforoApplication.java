package com.citizentech.semaforo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;

@SpringBootApplication
public class SemaforoApplication extends SpringBootServletInitializer {

    // Necessário para rodar como .war no Tomcat do Azure App Service
    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder builder) {
        return builder.sources(SemaforoApplication.class);
    }

    public static void main(String[] args) {
        SpringApplication.run(SemaforoApplication.class, args);
    }
}
