#
# ---- Server Base Node ----
FROM alpine:3.5 AS base
# install node
RUN apk add --no-cache nodejs-current tini
# set working directory
WORKDIR /root/app
# Set tini as entrypoint
ENTRYPOINT ["/sbin/tini", "--"]
# copy project file
COPY server/package.json .

# ---- Client build ----
FROM alpine:3.5 AS client-build
# install node
RUN apk add --no-cache nodejs-current tini
# set working directory
WORKDIR /root/app
COPY client .
# install ALL node_modules, including 'devDependencies'
RUN npm install && npm run build

#
# ---- Server dependencies ----
FROM base AS server-dependencies
# install node packages
RUN npm set progress=false && npm config set depth 0
RUN npm install --only=production 
# copy production node_modules aside
RUN cp -R node_modules prod_node_modules
# install ALL node_modules, including 'devDependencies'
RUN npm install

#
# ---- Build ----
# run linters, setup and build
FROM server-dependencies AS server-build
COPY server .
RUN  npm run build

#
# ---- Release ----
FROM base AS release
# copy production node_modules
COPY --from=server-dependencies /root/app/prod_node_modules ./node_modules
# copy public folder
COPY --from=client-build /root/app/dist ./public
# copy data
COPY --from=server-build /root/app/data ./data
# copy compiled dist
COPY --from=server-build /root/app/dist ./dist
# copy pm2.yml file
COPY --from=server-build /root/app/pm2.yml .
# expose port and define CMD
EXPOSE 8080
CMD npm run serve
